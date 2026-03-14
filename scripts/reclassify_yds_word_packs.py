from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

from dotenv import load_dotenv
from supabase import create_client

from static_content_common import pack_id_for_name


TARGET_PACK_NAMES = [
    "YDS Set 001",
    "YDS Set 002",
    "YDS Set 003",
    "YDS Set 004",
    "YDS Set 005",
]
OTHER_PACK_NAME = "Other"


def _retry(fn, action: str, retries: int = 5):
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


def _ensure_required_packs(client) -> None:
    payload = [
        {
            "id": pack_id_for_name(name),
            "name": name,
            "from_lang": "en",
            "to_lang": "tr",
        }
        for name in [*TARGET_PACK_NAMES, OTHER_PACK_NAME]
    ]
    _retry(
        lambda: client.table("packs").upsert(payload, on_conflict="name").execute(),
        action="packs upsert",
    )


def _build_preview_report(rows: list[dict[str, Any]], run_id: str) -> dict[str, Any]:
    target_counts: Dict[str, int] = {}
    reason_counts: Dict[str, int] = {}
    for row in rows:
        target_name = str(row.get("target_pack_name") or "").strip()
        reason = str(row.get("reason") or "").strip()
        if target_name:
            target_counts[target_name] = target_counts.get(target_name, 0) + 1
        if reason:
            reason_counts[reason] = reason_counts.get(reason, 0) + 1

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "source_pack_name": "YDS Set 001",
        "target_pack_names": TARGET_PACK_NAMES,
        "other_pack_name": OTHER_PACK_NAME,
        "summary": {
            "total_words": len(rows),
            "target_counts": target_counts,
            "reason_counts": reason_counts,
        },
        "items": rows,
    }


def _fetch_reclassification_rows(client, run_id: str) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    offset = 0
    page_size = 1000

    while True:
        response = _retry(
            lambda offset=offset: client.table("word_pack_reclassification_items")
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
        response = _retry(
            lambda batch=batch: client.table("words")
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
    if pack_id_list:
        for index in range(0, len(pack_id_list), 500):
            batch = pack_id_list[index : index + 500]
            if not batch:
                continue
            response = _retry(
                lambda batch=batch: client.table("packs")
                .select("id,name")
                .in_("id", batch)
                .execute(),
                action="packs fetch for reclassification report",
            )
            for row in response.data or []:
                pack_map[str(row.get("id") or "").strip()] = str(
                    row.get("name") or ""
                ).strip()

    rows: list[dict[str, Any]] = []
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="YDS Set 001 kelimelerini passage odak kelimelerine gore YDS Set 001..005 ve Other paketlerine dagitir."
    )
    parser.add_argument(
        "--mode",
        choices=("preview", "apply", "preview-and-apply"),
        default="preview",
    )
    parser.add_argument("--run-id", default="")
    parser.add_argument(
        "--report-file",
        default="json_output/word_pack_reclassification_report.json",
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
    report_file = Path(args.report_file).expanduser().resolve()

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

    _ensure_required_packs(client)

    preview_report: Optional[dict[str, Any]] = None
    run_id = str(args.run_id or "").strip()

    if args.mode in ("preview", "preview-and-apply"):
        preview_response = _retry(
            lambda: client.rpc(
                "admin_preview_word_pack_reclassification",
                params={
                    "p_source_pack_name": "YDS Set 001",
                    "p_target_pack_names": TARGET_PACK_NAMES,
                    "p_other_pack_name": OTHER_PACK_NAME,
                    "p_autolink_missing": True,
                    "p_autolink_limit": 10,
                },
            ).execute(),
            action="admin_preview_word_pack_reclassification rpc",
        )
        preview_rows = [dict(item) for item in (preview_response.data or [])]
        if not preview_rows:
            print("[ERROR] Preview sonucu bos dondu.")
            return 1

        run_id = str(preview_rows[0].get("run_id") or "").strip()
        if not run_id:
            print("[ERROR] Preview run_id uretmedi.")
            return 1

        preview_report = _build_preview_report(
            _fetch_reclassification_rows(client, run_id),
            run_id,
        )
        report_file.parent.mkdir(parents=True, exist_ok=True)
        report_file.write_text(
            json.dumps(preview_report, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    if args.mode in ("apply", "preview-and-apply"):
        if not run_id:
            print("[ERROR] --run-id zorunlu veya once preview calismis olmali.")
            return 1

        apply_response = _retry(
            lambda: client.rpc(
                "admin_apply_word_pack_reclassification",
                params={"p_run_id": run_id},
            ).execute(),
            action="admin_apply_word_pack_reclassification rpc",
        )
        apply_summary = dict(apply_response.data or {})

        if preview_report is not None:
            preview_report["apply_summary"] = apply_summary
            report_file.write_text(
                json.dumps(preview_report, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )

        print("[OK] Kelime paket reclassification apply tamamlandi")
        print(json.dumps(apply_summary, ensure_ascii=False, indent=2))
        return 0

    if preview_report is None:
        print("[ERROR] Preview raporu uretilemedi.")
        return 1

    print("[OK] Kelime paket reclassification preview tamamlandi")
    print(json.dumps(preview_report["summary"], ensure_ascii=False, indent=2))
    print(f"run_id={run_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
