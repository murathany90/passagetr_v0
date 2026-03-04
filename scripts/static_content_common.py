from __future__ import annotations

import csv
import hashlib
import re
import uuid
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Sequence, Tuple


SMART_QUOTES_MAP = str.maketrans(
    {
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u00a0": " ",
        "\ufeff": "",
    }
)

POS_CANONICAL_ORDER: List[str] = [
    "prep.",
    "phr. v.",
    "v.",
    "n.",
    "adj.",
    "adv.",
    "NP",
    "conj.",
    "det.",
    "modal",
]

ID_NAMESPACE = uuid.UUID("07cbf023-3cd8-4ae7-a892-097112e35d7f")

_POS_ALIAS_MAP: Dict[str, str] = {
    "prep": "prep.",
    "preposition": "prep.",
    "prepositional phrase": "prep.",
    "prep phr": "prep.",
    "prepositional phr": "prep.",
    "phrasal verb": "phr. v.",
    "phrasal v": "phr. v.",
    "phr v": "phr. v.",
    "verb": "v.",
    "v": "v.",
    "noun": "n.",
    "n": "n.",
    "adjective": "adj.",
    "adj": "adj.",
    "adverb": "adv.",
    "adv": "adv.",
    "np": "NP",
    "proper noun": "NP",
    "conjunction": "conj.",
    "conj": "conj.",
    "determiner": "det.",
    "det": "det.",
    "modal": "modal",
    "modal verb": "modal",
}


def clean_text(value: str) -> str:
    text = (value or "").translate(SMART_QUOTES_MAP)
    text = text.replace("\r", " ").replace("\n", " ")
    text = re.sub(r"[\u200b\u200c\u200d]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def normalize_header(value: str) -> str:
    text = clean_text(value).lower()
    text = text.replace("-", "_").replace(" ", "_")
    text = re.sub(r"_+", "_", text)
    return text.strip("_")


def normalize_word(value: str) -> str:
    text = clean_text(value).lower()
    return re.sub(r"\s+", " ", text).strip()


def build_search_key(normalized_word: str) -> str:
    text = re.sub(r"[^a-z0-9\s]", " ", normalized_word)
    text = re.sub(r"\s+", " ", text).strip()
    return text or normalized_word


def canonicalize_pos(raw_pos: str) -> Tuple[str | None, List[str]]:
    cleaned = clean_text(raw_pos)
    if not cleaned:
        return None, ["empty"]

    unknown_tokens: List[str] = []
    mapped_tokens: List[str] = []

    parts = [clean_text(part) for part in re.split(r"[;,]", cleaned)]
    for part in parts:
        if not part:
            continue
        normalized = _normalize_pos_piece(part)
        mapped = _POS_ALIAS_MAP.get(normalized)
        if not mapped:
            unknown_tokens.append(part)
            continue
        mapped_tokens.append(mapped)

    if unknown_tokens or not mapped_tokens:
        return None, unknown_tokens

    token_set = set(mapped_tokens)
    ordered = [token for token in POS_CANONICAL_ORDER if token in token_set]
    if not ordered:
        return None, ["no_valid_token"]

    return ";".join(ordered), []


def chunked(values: Sequence[dict], chunk_size: int) -> Iterator[Sequence[dict]]:
    if chunk_size <= 0:
        yield values
        return
    for i in range(0, len(values), chunk_size):
        yield values[i : i + chunk_size]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_csv_rows(path: Path) -> Tuple[Dict[str, int], List[List[str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle, delimiter=";")
        header = next(reader, None)
        if not header:
            raise ValueError(f"CSV bos veya header yok: {path}")

        mapping: Dict[str, int] = {}
        for idx, value in enumerate(header):
            key = normalize_header(str(value or ""))
            if key:
                mapping[key] = idx

        rows: List[List[str]] = []
        for row in reader:
            rows.append([str(cell or "") for cell in row])
        return mapping, rows


def read_field(row: List[str], mapping: Dict[str, int], key: str) -> str:
    if key not in mapping:
        return ""
    idx = mapping[key]
    if idx < 0 or idx >= len(row):
        return ""
    return row[idx]


def deterministic_uuid(kind: str, value: str) -> str:
    source = f"{kind}|{normalize_word(value)}"
    return str(uuid.uuid5(ID_NAMESPACE, source))


def pack_id_for_name(pack_name: str) -> str:
    return deterministic_uuid("pack", pack_name)


def word_id_for_values(pack_name: str, en_word: str, pos: str) -> str:
    normalized_pack = normalize_word(pack_name)
    normalized_word = normalize_word(en_word)
    normalized_pos = normalize_word(pos)
    source = f"{normalized_pack}|{normalized_word}|{normalized_pos}"
    return deterministic_uuid("word", source)


def passage_id_for_title(title: str) -> str:
    return deterministic_uuid("passage", title)


def sentence_id_for_title_idx(title: str, idx: int) -> str:
    source = f"{normalize_word(title)}|{int(idx)}"
    return deterministic_uuid("sentence", source)


def dictionary_entry_id_for_hash(hash_value: str) -> str:
    return deterministic_uuid("dict-entry", hash_value)


def _normalize_pos_piece(value: str) -> str:
    text = clean_text(value).lower()
    text = text.replace(".", " ")
    text = re.sub(r"\s+", " ", text)
    return text.strip()
