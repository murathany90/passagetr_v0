from __future__ import annotations

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence

from dotenv import load_dotenv
from supabase import Client, create_client

from static_content_common import (
    canonicalize_pos,
    chunked,
    clean_text,
    normalize_header,
    normalize_word,
    pack_id_for_name,
    passage_id_for_title,
    read_csv_rows,
    read_field,
    sentence_id_for_title_idx,
    sha256_file,
    word_id_for_values,
)


REQUIRED_WORD_COLUMNS = ("en_word", "tr_meaning", "pos")
REQUIRED_PASSAGE_COLUMNS = ("pack_name", "title", "level", "tags_raw", "category")
REQUIRED_SENTENCE_COLUMNS = ("passage_title", "idx", "sentence_en")


@dataclass
class WordsStats:
    rows_read: int = 0
    rows_loaded: int = 0
    duplicate_rows: int = 0
    invalid_rows: int = 0
    empty_meaning_rows: int = 0
    invalid_pos_rows: int = 0


@dataclass
class PassagesStats:
    rows_read: int = 0
    rows_loaded: int = 0
    invalid_rows: int = 0


@dataclass
class SentencesStats:
    rows_read: int = 0
    rows_loaded: int = 0
    invalid_rows: int = 0
    skipped_empty_rows: int = 0
    unmapped_passage_rows: int = 0
    reindexed_rows: int = 0


@dataclass
class IdParityStats:
    ok: bool = True
    word_mismatch_count: int = 0
    passage_mismatch_count: int = 0
    sentence_mismatch_count: int = 0


class StaticContentImporter:
    def __init__(
        self,
        client: Client,
        words_file: Path,
        passages_file: Path,
        sentences_file: Path,
        mode: str,
        batch_size: int,
        report_file: Path,
        word_pack_report_file: Path,
        skip_word_pack_reclassification: bool,
    ) -> None:
        self.client = client
        self.words_file = words_file
        self.passages_file = passages_file
        self.sentences_file = sentences_file
        self.mode = mode
        self.batch_size = batch_size
        self.report_file = report_file
        self.word_pack_report_file = word_pack_report_file
        self.skip_word_pack_reclassification = skip_word_pack_reclassification

        self.words_stats = WordsStats()
        self.passages_stats = PassagesStats()
        self.sentences_stats = SentencesStats()
        self.id_parity_stats = IdParityStats()

    def run(self) -> Dict[str, Any]:
        started = time.perf_counter()

        words_mapping, words_rows = read_csv_rows(self.words_file)
        passages_mapping, passages_rows = read_csv_rows(self.passages_file)
        sentences_mapping, sentences_rows = read_csv_rows(self.sentences_file)

        self._ensure_required_headers(
            words_mapping, REQUIRED_WORD_COLUMNS, "YDS_Set_001.csv"
        )
        self._ensure_required_headers(
            passages_mapping, REQUIRED_PASSAGE_COLUMNS, "readings_passages.csv"
        )
        self._ensure_required_headers(
            sentences_mapping, REQUIRED_SENTENCE_COLUMNS, "readings_sentences.csv"
        )

        if self.mode == "replace":
            self._reset_static_content()

        pack_names = self._collect_pack_names(passages_rows, passages_mapping)
        pack_names.add("YDS Set 001")
        pack_names.add("Other")
        pack_id_by_name = self._upsert_packs(pack_names)
        set001_pack_name = "YDS Set 001"
        set001_pack_id = pack_id_by_name.get("YDS Set 001")
        if not set001_pack_id:
            raise RuntimeError("YDS Set 001 pack_id resolve edilemedi.")

        words_payload = self._build_words_payload(
            words_rows,
            words_mapping,
            set001_pack_name,
            set001_pack_id,
        )
        self._insert_words(words_payload)

        passages_payload, passage_id_by_title = self._build_passages_payload(
            passages_rows, passages_mapping, pack_id_by_name
        )
        self._insert_passages(passages_payload)

        sentence_payload = self._build_sentences_payload(
            sentences_rows, sentences_mapping, passage_id_by_title
        )
        self._insert_sentences(sentence_payload)

        word_pack_reclassification: Optional[Dict[str, Any]] = None
        reclassified_word_ids: set[str] = set()
        if not self.skip_word_pack_reclassification:
            word_pack_reclassification = self._run_word_pack_reclassification()
            reclassified_word_ids = set(
                word_pack_reclassification.get("word_ids", []) or []
            )
            word_pack_reclassification = {
                key: value
                for key, value in word_pack_reclassification.items()
                if key != "word_ids"
            }

        self.id_parity_stats = self._validate_id_parity(
            pack_id_by_name,
            source_pack_name=set001_pack_name,
            reclassified_word_ids=reclassified_word_ids,
        )

        elapsed_ms = int((time.perf_counter() - started) * 1000)
        report = {
            "mode": self.mode,
            "batch_size": self.batch_size,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "duration_ms": elapsed_ms,
            "source_files": {
                "words_file": str(self.words_file),
                "passages_file": str(self.passages_file),
                "sentences_file": str(self.sentences_file),
            },
            "checksums": {
                "words_sha256": sha256_file(self.words_file),
                "passages_sha256": sha256_file(self.passages_file),
                "sentences_sha256": sha256_file(self.sentences_file),
            },
            "packs": {
                "count": len(pack_id_by_name),
                "names": sorted(pack_id_by_name.keys()),
            },
            "words": self.words_stats.__dict__,
            "passages": self.passages_stats.__dict__,
            "sentences": self.sentences_stats.__dict__,
            "id_parity": self.id_parity_stats.__dict__,
            "id_parity_ok": self.id_parity_stats.ok,
            "word_pack_reclassification": word_pack_reclassification
            if word_pack_reclassification is not None
            else {
                "skipped": True,
                "report_file": str(self.word_pack_report_file),
            },
        }

        self.report_file.parent.mkdir(parents=True, exist_ok=True)
        self.report_file.write_text(
            json.dumps(report, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        if not self.id_parity_stats.ok:
            raise RuntimeError(
                "ID parity kontrolu basarisiz. "
                f"words={self.id_parity_stats.word_mismatch_count}, "
                f"passages={self.id_parity_stats.passage_mismatch_count}, "
                f"sentences={self.id_parity_stats.sentence_mismatch_count}"
            )
        return report

    def _build_words_payload(
        self,
        rows: List[List[str]],
        mapping: Dict[str, int],
        pack_name: str,
        pack_id: str,
    ) -> List[Dict[str, Any]]:
        payload: List[Dict[str, Any]] = []
        dedupe: set[tuple[str, str]] = set()

        for row in rows:
            self.words_stats.rows_read += 1
            en_word = clean_text(read_field(row, mapping, "en_word"))
            tr_meaning = clean_text(read_field(row, mapping, "tr_meaning"))
            pos_raw = clean_text(read_field(row, mapping, "pos"))
            example_en = clean_text(read_field(row, mapping, "example_en"))
            example_tr = clean_text(read_field(row, mapping, "example_tr"))
            synonyms_raw = clean_text(read_field(row, mapping, "synonyms_raw"))
            antonyms_raw = clean_text(read_field(row, mapping, "antonyms_raw"))
            level = clean_text(read_field(row, mapping, "level"))
            tags_raw = clean_text(read_field(row, mapping, "tags_raw"))
            notes = clean_text(read_field(row, mapping, "notes"))

            if not en_word:
                self.words_stats.invalid_rows += 1
                continue

            if not tr_meaning:
                self.words_stats.empty_meaning_rows += 1
                continue

            pos_canonical, unknown_tokens = canonicalize_pos(pos_raw)
            if not pos_canonical:
                self.words_stats.invalid_pos_rows += 1
                self.words_stats.invalid_rows += 1
                if unknown_tokens:
                    print(
                        "[WARN] POS normalize edilemedi:",
                        en_word,
                        "| raw=",
                        pos_raw,
                        "| unknown=",
                        ",".join(unknown_tokens),
                    )
                continue

            dedupe_key = (normalize_word(en_word), pos_canonical)
            if dedupe_key in dedupe:
                self.words_stats.duplicate_rows += 1
                continue
            dedupe.add(dedupe_key)

            word_id = word_id_for_values(pack_name, en_word, pos_canonical)
            payload.append(
                {
                    "id": word_id,
                    "pack_id": pack_id,
                    "en_word": en_word,
                    "tr_meaning": tr_meaning,
                    "pos": pos_canonical,
                    "pos_raw": pos_raw,
                    "example_en": example_en or en_word,
                    "example_tr": example_tr or None,
                    "synonyms_raw": synonyms_raw or None,
                    "antonyms_raw": antonyms_raw or None,
                    "level": level or None,
                    "tags_raw": tags_raw or None,
                    "notes": notes or None,
                }
            )

        return payload

    def _build_passages_payload(
        self,
        rows: List[List[str]],
        mapping: Dict[str, int],
        pack_id_by_name: Dict[str, str],
    ) -> tuple[List[Dict[str, Any]], Dict[str, str]]:
        payload: List[Dict[str, Any]] = []
        passage_id_by_title: Dict[str, str] = {}
        seen_titles: set[str] = set()

        for row in rows:
            self.passages_stats.rows_read += 1
            pack_name = clean_text(read_field(row, mapping, "pack_name"))
            title = clean_text(read_field(row, mapping, "title"))
            level = clean_text(read_field(row, mapping, "level"))
            tags_raw = clean_text(read_field(row, mapping, "tags_raw"))
            category = clean_text(read_field(row, mapping, "category"))

            if not pack_name or not title:
                self.passages_stats.invalid_rows += 1
                continue

            pack_id = pack_id_by_name.get(pack_name)
            if not pack_id:
                self.passages_stats.invalid_rows += 1
                continue

            # reading_sentences baglamasi passage_title uzerinden oldugu icin
            # passage title tekil kalacak sekilde dedupe ediyoruz.
            title_key = normalize_word(title)
            if title_key in seen_titles:
                self.passages_stats.invalid_rows += 1
                continue
            seen_titles.add(title_key)
            passage_id = passage_id_for_title(title_key)
            passage_id_by_title[title_key] = passage_id

            payload.append(
                {
                    "id": passage_id,
                    "pack_id": pack_id,
                    "pack_name": pack_name,
                    "title": title,
                    "level": level or None,
                    "tags_raw": tags_raw or None,
                    "category": category or None,
                }
            )
        return payload, passage_id_by_title

    def _build_sentences_payload(
        self,
        rows: List[List[str]],
        mapping: Dict[str, int],
        passage_id_by_title: Dict[str, str],
    ) -> List[Dict[str, Any]]:
        grouped: Dict[str, List[Dict[str, Any]]] = {}

        for row in rows:
            self.sentences_stats.rows_read += 1
            passage_title = clean_text(read_field(row, mapping, "passage_title"))
            idx_raw = clean_text(read_field(row, mapping, "idx"))
            sentence_en = clean_text(read_field(row, mapping, "sentence_en"))
            sentence_tr = clean_text(read_field(row, mapping, "sentence_tr"))

            if not passage_title and not idx_raw and not sentence_en and not sentence_tr:
                self.sentences_stats.skipped_empty_rows += 1
                continue

            if not passage_title or not idx_raw or not sentence_en:
                self.sentences_stats.invalid_rows += 1
                continue

            try:
                idx_value = int(idx_raw)
            except ValueError:
                self.sentences_stats.invalid_rows += 1
                continue

            grouped.setdefault(passage_title, []).append(
                {
                    "passage_title": passage_title,
                    "idx": idx_value,
                    "sentence_en": sentence_en,
                    "sentence_tr": sentence_tr or None,
                }
            )

        normalized: List[Dict[str, Any]] = []
        for passage_title, items in grouped.items():
            idx_values = [item["idx"] for item in items]
            has_invalid_idx = any(idx <= 0 for idx in idx_values)
            has_duplicate_idx = len(set(idx_values)) != len(idx_values)
            need_reindex = has_invalid_idx or has_duplicate_idx

            if need_reindex:
                self.sentences_stats.reindexed_rows += len(items)
                for new_idx, item in enumerate(items, start=1):
                    next_item = dict(item)
                    next_item["idx"] = new_idx
                    normalized.append(next_item)
            else:
                normalized.extend(items)

        payload: List[Dict[str, Any]] = []
        for item in normalized:
            normalized_title = normalize_word(item["passage_title"])
            passage_id = passage_id_by_title.get(normalized_title)
            if not passage_id:
                self.sentences_stats.unmapped_passage_rows += 1
                continue
            sentence_id = sentence_id_for_title_idx(
                item["passage_title"],
                item["idx"],
            )
            payload.append(
                {
                    "id": sentence_id,
                    "passage_id": passage_id,
                    "passage_title": item["passage_title"],
                    "idx": item["idx"],
                    "sentence_en": item["sentence_en"],
                    "sentence_tr": item["sentence_tr"],
                }
            )

        return payload

    def _collect_pack_names(
        self,
        rows: List[List[str]],
        mapping: Dict[str, int],
    ) -> set[str]:
        names: set[str] = set()
        for row in rows:
            pack_name = clean_text(read_field(row, mapping, "pack_name"))
            if pack_name:
                names.add(pack_name)
        return names

    def _upsert_packs(self, pack_names: set[str]) -> Dict[str, str]:
        if not pack_names:
            return {}

        payload = [
            {
                "id": pack_id_for_name(name),
                "name": name,
                "from_lang": "en",
                "to_lang": "tr",
            }
            for name in sorted(pack_names)
        ]
        self._retry(
            lambda: self.client.table("packs")
            .upsert(payload, on_conflict="name")
            .execute(),
            action="packs upsert",
        )

        response = self._retry(
            lambda: self.client.table("packs")
            .select("id,name")
            .in_("name", sorted(pack_names))
            .execute(),
            action="packs fetch",
        )
        result: Dict[str, str] = {}
        for row in response.data or []:
            name = str(row.get("name") or "").strip()
            row_id = str(row.get("id") or "").strip()
            if name and row_id:
                result[name] = row_id
        return result

    def _insert_words(self, payload: List[Dict[str, Any]]) -> None:
        for rows in chunked(payload, self.batch_size):
            self._retry(
                lambda rows=rows: self.client.table("words")
                .upsert(list(rows), on_conflict="id")
                .execute(),
                action="words upsert",
            )
            self.words_stats.rows_loaded += len(rows)

    def _insert_passages(self, payload: List[Dict[str, Any]]) -> None:
        for rows in chunked(payload, self.batch_size):
            self._retry(
                lambda rows=rows: self.client.table("reading_passages")
                .upsert(list(rows), on_conflict="id")
                .execute(),
                action="reading_passages upsert",
            )
            self.passages_stats.rows_loaded += len(rows)

    def _insert_sentences(self, payload: List[Dict[str, Any]]) -> None:
        for rows in chunked(payload, self.batch_size):
            self._retry(
                lambda rows=rows: self.client.table("reading_passage_sentences")
                .upsert(list(rows), on_conflict="id")
                .execute(),
                action="reading_passage_sentences upsert",
            )
            self.sentences_stats.rows_loaded += len(rows)

    def _validate_id_parity(
        self,
        pack_id_by_name: Dict[str, str],
        source_pack_name: str,
        reclassified_word_ids: set[str],
    ) -> IdParityStats:
        stats = IdParityStats()
        pack_name_by_id: Dict[str, str] = {
            value: key for key, value in pack_id_by_name.items()
        }

        words_rows = self._fetch_all_rows(
            table="words",
            columns="id,pack_id,en_word,pos",
            action="words parity fetch",
        )
        for row in words_rows:
            row_id = str(row.get("id") or "").strip()
            pack_id = str(row.get("pack_id") or "").strip()
            en_word = str(row.get("en_word") or "")
            pos = str(row.get("pos") or "")
            pack_name = (
                source_pack_name
                if row_id in reclassified_word_ids
                else pack_name_by_id.get(pack_id, "")
            )
            expected = word_id_for_values(pack_name, en_word, pos)
            if not row_id or row_id != expected:
                stats.word_mismatch_count += 1

        passage_rows = self._fetch_all_rows(
            table="reading_passages",
            columns="id,title",
            action="reading_passages parity fetch",
        )
        for row in passage_rows:
            row_id = str(row.get("id") or "").strip()
            title = str(row.get("title") or "")
            expected = passage_id_for_title(title)
            if not row_id or row_id != expected:
                stats.passage_mismatch_count += 1

        sentence_rows = self._fetch_all_rows(
            table="reading_passage_sentences",
            columns="id,passage_title,idx",
            action="reading_passage_sentences parity fetch",
        )
        for row in sentence_rows:
            row_id = str(row.get("id") or "").strip()
            passage_title = str(row.get("passage_title") or "")
            idx_value = row.get("idx")
            if isinstance(idx_value, str):
                try:
                    idx_int = int(idx_value)
                except ValueError:
                    stats.sentence_mismatch_count += 1
                    continue
            elif isinstance(idx_value, int):
                idx_int = idx_value
            else:
                stats.sentence_mismatch_count += 1
                continue

            expected = sentence_id_for_title_idx(passage_title, idx_int)
            if not row_id or row_id != expected:
                stats.sentence_mismatch_count += 1

        stats.ok = (
            stats.word_mismatch_count == 0
            and stats.passage_mismatch_count == 0
            and stats.sentence_mismatch_count == 0
        )
        return stats

    def _run_word_pack_reclassification(self) -> Dict[str, Any]:
        preview_response = self._retry(
            lambda: self.client.rpc(
                "admin_preview_word_pack_reclassification",
                params={
                    "p_source_pack_name": "YDS Set 001",
                    "p_target_pack_names": [
                        "YDS Set 001",
                        "YDS Set 002",
                        "YDS Set 003",
                        "YDS Set 004",
                        "YDS Set 005",
                    ],
                    "p_other_pack_name": "Other",
                    "p_autolink_missing": True,
                    "p_autolink_limit": 10,
                },
            ).execute(),
            action="admin_preview_word_pack_reclassification rpc",
        )

        preview_rows = [dict(item) for item in (preview_response.data or [])]
        if not preview_rows:
            raise RuntimeError(
                "Kelime paket yeniden siniflandirma preview sonucu bos dondu."
            )

        run_id = str(preview_rows[0].get("run_id") or "").strip()
        if not run_id:
            raise RuntimeError("Kelime paket preview run_id uretmedi.")

        preview_rows = self._fetch_reclassification_rows(run_id)
        target_counts: Dict[str, int] = {}
        reason_counts: Dict[str, int] = {}
        for row in preview_rows:
            target_name = str(row.get("target_pack_name") or "").strip()
            reason = str(row.get("reason") or "").strip()
            if target_name:
                target_counts[target_name] = target_counts.get(target_name, 0) + 1
            if reason:
                reason_counts[reason] = reason_counts.get(reason, 0) + 1

        preview_report = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "run_id": run_id,
            "source_pack_name": "YDS Set 001",
            "target_pack_names": [
                "YDS Set 001",
                "YDS Set 002",
                "YDS Set 003",
                "YDS Set 004",
                "YDS Set 005",
            ],
            "other_pack_name": "Other",
            "summary": {
                "total_words": len(preview_rows),
                "target_counts": target_counts,
                "reason_counts": reason_counts,
            },
            "items": preview_rows,
        }
        self.word_pack_report_file.parent.mkdir(parents=True, exist_ok=True)
        self.word_pack_report_file.write_text(
            json.dumps(preview_report, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        apply_response = self._retry(
            lambda: self.client.rpc(
                "admin_apply_word_pack_reclassification",
                params={"p_run_id": run_id},
            ).execute(),
            action="admin_apply_word_pack_reclassification rpc",
        )
        apply_summary = dict(apply_response.data or {})

        return {
            "skipped": False,
            "run_id": run_id,
            "report_file": str(self.word_pack_report_file),
            "preview_summary": preview_report["summary"],
            "apply_summary": apply_summary,
            "word_ids": [
                str(row.get("word_id") or "").strip()
                for row in preview_rows
                if str(row.get("word_id") or "").strip()
            ],
        }

    def _fetch_reclassification_rows(self, run_id: str) -> List[Dict[str, Any]]:
        items: List[Dict[str, Any]] = []
        offset = 0
        page_size = 1000

        while True:
            response = self._retry(
                lambda offset=offset: self.client.table(
                    "word_pack_reclassification_items"
                )
                .select(
                    "word_id,current_pack_id,target_pack_id,reason,set_hit_counts,linked_passage_count"
                )
                .eq("run_id", run_id)
                .order("word_id", desc=False)
                .range(offset, offset + page_size - 1)
                .execute(),
                action="word_pack_reclassification_items fetch",
            )
            chunk = [dict(item) for item in (response.data or [])]
            items.extend(chunk)
            if len(chunk) < page_size:
                break
            offset += len(chunk)

        word_ids = [str(item.get("word_id") or "").strip() for item in items]
        pack_ids = {
            str(item.get("current_pack_id") or "").strip()
            for item in items
        } | {
            str(item.get("target_pack_id") or "").strip()
            for item in items
        }
        pack_ids.discard("")

        word_map: Dict[str, str] = {}
        for index in range(0, len(word_ids), 500):
            batch = [word_id for word_id in word_ids[index : index + 500] if word_id]
            if not batch:
                continue
            response = self._retry(
                lambda batch=batch: self.client.table("words")
                .select("id,en_word")
                .in_("id", batch)
                .execute(),
                action="words fetch for reclassification report",
            )
            for row in response.data or []:
                word_map[str(row.get("id") or "").strip()] = str(
                    row.get("en_word") or ""
                ).strip()

        pack_map: Dict[str, str] = {}
        pack_id_list = [pack_id for pack_id in pack_ids if pack_id]
        for index in range(0, len(pack_id_list), 500):
            batch = pack_id_list[index : index + 500]
            if not batch:
                continue
            response = self._retry(
                lambda batch=batch: self.client.table("packs")
                .select("id,name")
                .in_("id", batch)
                .execute(),
                action="packs fetch for reclassification report",
            )
            for row in response.data or []:
                pack_map[str(row.get("id") or "").strip()] = str(
                    row.get("name") or ""
                ).strip()

        rows: List[Dict[str, Any]] = []
        for item in items:
            word_id = str(item.get("word_id") or "").strip()
            current_pack_id = str(item.get("current_pack_id") or "").strip()
            target_pack_id = str(item.get("target_pack_id") or "").strip()
            rows.append(
                {
                    "run_id": run_id,
                    "word_id": word_id,
                    "en_word": word_map.get(word_id, ""),
                    "current_pack_name": pack_map.get(current_pack_id, ""),
                    "target_pack_name": pack_map.get(target_pack_id, ""),
                    "reason": str(item.get("reason") or "").strip(),
                    "set_hit_counts": item.get("set_hit_counts") or {},
                    "linked_passage_count": int(item.get("linked_passage_count") or 0),
                }
            )
        return rows

    def _fetch_all_rows(self, table: str, columns: str, action: str) -> List[Dict[str, Any]]:
        rows: List[Dict[str, Any]] = []
        page_size = 1000
        offset = 0

        while True:
            response = self._retry(
                lambda offset=offset: self.client.table(table)
                .select(columns)
                .order("id", desc=False)
                .range(offset, offset + page_size - 1)
                .execute(),
                action=action,
            )
            chunk = [dict(item) for item in (response.data or [])]
            rows.extend(chunk)
            if len(chunk) < page_size:
                break
            offset += len(chunk)
        return rows

    def _reset_static_content(self) -> None:
        self._retry(
            lambda: self.client.rpc("admin_reset_static_content").execute(),
            action="admin_reset_static_content rpc",
        )

    def _ensure_required_headers(
        self,
        mapping: Dict[str, int],
        required_headers: Sequence[str],
        label: str,
    ) -> None:
        missing = [header for header in required_headers if normalize_header(header) not in mapping]
        if missing:
            raise ValueError(f"{label} eksik kolonlar: {', '.join(missing)}")

    def _retry(self, fn, action: str, retries: int = 5):
        last_error: Optional[Exception] = None
        for attempt in range(1, retries + 1):
            try:
                return fn()
            except Exception as err:  # noqa: BLE001
                last_error = err
                message = str(err).lower()
                retryable = any(
                    token in message
                    for token in (
                        "520",
                        "timeout",
                        "timed out",
                        "connection",
                        "temporarily",
                        "502",
                        "503",
                        "504",
                        "rate limit",
                    )
                )
                if attempt >= retries or not retryable:
                    break
                sleep_seconds = min(2**attempt, 20)
                print(
                    f"[WARN] {action} hatasi (deneme {attempt}/{retries}): {err}. "
                    f"{sleep_seconds}s sonra tekrar deneniyor."
                )
                time.sleep(sleep_seconds)
        if last_error is not None:
            raise last_error
        raise RuntimeError(f"Bilinmeyen hata: {action}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Words + Readings CSV verisini Supabase'e (replace) import eder."
    )
    parser.add_argument("--words-file", required=True)
    parser.add_argument("--passages-file", required=True)
    parser.add_argument("--sentences-file", required=True)
    parser.add_argument(
        "--mode",
        default="replace",
        choices=("replace",),
        help="Bu scriptte sadece replace modu desteklenir.",
    )
    parser.add_argument("--batch-size", type=int, default=1000)
    parser.add_argument(
        "--report-file",
        default="json_output/static_content_import_report.json",
    )
    parser.add_argument(
        "--word-pack-report-file",
        default="json_output/word_pack_reclassification_report.json",
    )
    parser.add_argument(
        "--skip-word-pack-reclassification",
        action="store_true",
        help="YDS Set 001 kelimelerini passage odak kelimelerine gore yeniden paketleme adimini atlar.",
    )
    parser.add_argument("--supabase-url", default="", help="Opsiyonel SUPABASE_URL override")
    parser.add_argument(
        "--supabase-key",
        default="",
        help="Opsiyonel SUPABASE_SERVICE_ROLE_KEY override",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    words_file = Path(args.words_file).expanduser().resolve()
    passages_file = Path(args.passages_file).expanduser().resolve()
    sentences_file = Path(args.sentences_file).expanduser().resolve()
    report_file = Path(args.report_file).expanduser().resolve()
    word_pack_report_file = Path(args.word_pack_report_file).expanduser().resolve()

    for path in (words_file, passages_file, sentences_file):
        if not path.exists():
            print(f"[ERROR] Dosya bulunamadi: {path}")
            return 1

    if args.batch_size <= 0:
        print("[ERROR] --batch-size pozitif olmalidir.")
        return 1

    load_dotenv(dotenv_path=Path(".env"), override=True, encoding="utf-8-sig")

    def _get_env(name: str) -> str:
        return (os.getenv(name, "") or os.getenv(f"\ufeff{name}", "")).strip()

    url = (args.supabase_url or _get_env("SUPABASE_URL")).strip()
    key = (
        args.supabase_key
        or _get_env("SUPABASE_SERVICE_ROLE_KEY")
        or _get_env("SUPABASE_KEY")
    ).strip()

    if not url or not key:
        print("[ERROR] SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY zorunludur.")
        return 1

    try:
        client = create_client(url, key)
    except Exception as err:  # noqa: BLE001
        print(f"[ERROR] Supabase istemcisi olusturulamadi: {err}")
        return 1

    importer = StaticContentImporter(
        client=client,
        words_file=words_file,
        passages_file=passages_file,
        sentences_file=sentences_file,
        mode=args.mode,
        batch_size=args.batch_size,
        report_file=report_file,
        word_pack_report_file=word_pack_report_file,
        skip_word_pack_reclassification=bool(args.skip_word_pack_reclassification),
    )

    try:
        report = importer.run()
    except Exception as err:  # noqa: BLE001
        print(f"[ERROR] Static content import basarisiz: {err}")
        return 1

    print("[OK] Static content import tamamlandi")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
