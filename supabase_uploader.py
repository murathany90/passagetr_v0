"""
Supabase uploader for grammar modules JSON.

Kullanim:
  python supabase_uploader.py --json-file json_output/tum_gramer_modulleri.json --mode upsert
  python supabase_uploader.py --mode replace --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from typing import Any, Dict, List

from dotenv import load_dotenv
from supabase import Client, create_client


TABLES_IN_DELETE_ORDER = [
    "gramer_testler",
    "gramer_ornekler",
    "gramer_sayfalari",
    "gramer_modulleri",
]


class SupabaseUploader:
    def __init__(self, url: str, key: str, dry_run: bool = False) -> None:
        self.dry_run = dry_run
        self.client: Client | None = None
        if not dry_run:
            if not url or not key:
                raise ValueError("SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY zorunludur.")
            self.client = create_client(url, key)

    def upload_modules(self, modules: List[Dict[str, Any]], mode: str = "upsert") -> Dict[str, Any]:
        if mode not in {"upsert", "replace"}:
            raise ValueError("mode yalnizca upsert veya replace olabilir.")

        summary = {
            "mode": mode,
            "dry_run": self.dry_run,
            "module_count": len(modules),
            "page_count": 0,
            "example_count": 0,
            "test_count": 0,
        }

        if mode == "replace" and not self.dry_run:
            self.clear_existing_data()

        for module in modules:
            print(f"[INFO] Modul yukleniyor: {module.get('sira')} - {module.get('baslik')}")
            module_id = self.upsert_module(module)
            pages = module.get("sayfalar", [])

            for page in pages:
                summary["page_count"] += 1
                page_id = self.upsert_page(module_id, page)

                examples = page.get("examples", [])
                tests = page.get("mini_tests") or []
                if not tests and page.get("mini_test"):
                    tests = [page["mini_test"]]

                summary["example_count"] += len(examples)
                summary["test_count"] += len(tests)

                if self.dry_run:
                    continue

                assert self.client is not None
                self.with_retry(
                    lambda: self.client.table("gramer_ornekler").delete().eq("sayfa_id", page_id).execute(),
                    action=f"ornek silme sayfa_id={page_id}",
                )
                self.with_retry(
                    lambda: self.client.table("gramer_testler").delete().eq("sayfa_id", page_id).execute(),
                    action=f"test silme sayfa_id={page_id}",
                )

                example_rows = []
                for idx, example in enumerate(examples):
                    example_rows.append(
                        {
                            "sayfa_id": page_id,
                            "sira": idx,
                            "ingilizce": (example.get("en") or "").strip(),
                            "turkce": (example.get("tr") or "").strip(),
                            "aciklama": (example.get("description") or "").strip(),
                        }
                    )
                if example_rows:
                    self.with_retry(
                        lambda rows=example_rows: self.client.table("gramer_ornekler").insert(rows).execute(),
                        action=f"ornek ekleme sayfa_id={page_id}",
                    )

                test_rows = []
                for idx, test in enumerate(tests):
                    test_rows.append(
                        {
                            "sayfa_id": page_id,
                            "sira": idx,
                            "soru": (test.get("question") or "").strip(),
                            "secenekler_json": test.get("options") or {},
                            "dogru_cevap": (test.get("correct") or "").strip(),
                            "aciklama": (test.get("explanation") or "").strip(),
                        }
                    )
                if test_rows:
                    self.with_retry(
                        lambda rows=test_rows: self.client.table("gramer_testler").insert(rows).execute(),
                        action=f"test ekleme sayfa_id={page_id}",
                    )

        return summary

    def upsert_module(self, module: Dict[str, Any]) -> int:
        payload = {
            "sira": self.to_int(module.get("sira"), default=0),
            "baslik": module.get("baslik") or "",
            "dosya_adi": module.get("dosya_adi") or "",
            "toplam_sayfa": self.to_int(module.get("toplam_sayfa"), default=0),
            "icon": module.get("icon") or "📘",
            "renk": module.get("renk") or "#4776E6",
        }

        if self.dry_run:
            return payload["sira"] or 0

        assert self.client is not None
        response = self.with_retry(
            lambda: self.client.table("gramer_modulleri").upsert(payload, on_conflict="sira").execute(),
            action=f"modul upsert sira={payload['sira']}",
        )
        if response.data:
            return int(response.data[0]["id"])

        lookup = self.with_retry(
            lambda: self.client.table("gramer_modulleri").select("id").eq("sira", payload["sira"]).limit(1).execute(),
            action=f"modul lookup sira={payload['sira']}",
        )
        if not lookup.data:
            raise RuntimeError(f"Modul upsert sonrasi ID bulunamadi: sira={payload['sira']}")
        return int(lookup.data[0]["id"])

    def upsert_page(self, module_id: int, page: Dict[str, Any]) -> int:
        payload = {
            "modul_id": module_id,
            "sayfa_no": self.to_int(page.get("page_number"), default=0),
            "baslik": page.get("title") or "",
            "icerik_html": page.get("content_html") or "",
            "kelime_sayisi": self.to_int(page.get("word_count"), default=0),
        }

        if self.dry_run:
            # Dry-run icin deterministic bir pseudo id.
            return (module_id * 1000) + payload["sayfa_no"]

        assert self.client is not None
        response = self.with_retry(
            lambda: self.client.table("gramer_sayfalari")
            .upsert(payload, on_conflict="modul_id,sayfa_no")
            .execute(),
            action=f"sayfa upsert modul_id={module_id} sayfa_no={payload['sayfa_no']}",
        )
        if response.data:
            return int(response.data[0]["id"])

        lookup = self.with_retry(
            lambda: self.client.table("gramer_sayfalari")
            .select("id")
            .eq("modul_id", module_id)
            .eq("sayfa_no", payload["sayfa_no"])
            .limit(1)
            .execute(),
            action=f"sayfa lookup modul_id={module_id} sayfa_no={payload['sayfa_no']}",
        )
        if not lookup.data:
            raise RuntimeError(
                f"Sayfa upsert sonrasi ID bulunamadi: modul_id={module_id}, sayfa_no={payload['sayfa_no']}"
            )
        return int(lookup.data[0]["id"])

    def clear_existing_data(self) -> None:
        assert self.client is not None
        for table in TABLES_IN_DELETE_ORDER:
            self.with_retry(
                lambda table_name=table: self.client.table(table_name).delete().gt("id", 0).execute(),
                action=f"tablo temizleme {table}",
            )

    def with_retry(self, fn, action: str, retries: int = 5):
        last_error: Exception | None = None
        for attempt in range(1, retries + 1):
            try:
                return fn()
            except Exception as err:  # noqa: BLE001
                last_error = err
                message = str(err)
                retryable = any(
                    token in message.lower()
                    for token in (
                        " 520",
                        "unknown error",
                        "timeout",
                        "timed out",
                        "connection",
                        "temporarily",
                        "502",
                        "503",
                        "504",
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

    @staticmethod
    def to_int(value: Any, default: int = 0) -> int:
        if value is None:
            return default
        match = None
        try:
            import re

            match = re.search(r"\d+", str(value))
        except Exception:
            match = None
        if not match:
            return default
        try:
            return int(match.group(0))
        except ValueError:
            return default


def load_modules(json_file: Path) -> List[Dict[str, Any]]:
    if not json_file.exists():
        raise FileNotFoundError(f"JSON dosyasi bulunamadi: {json_file}")
    payload = json.loads(json_file.read_text(encoding="utf-8"))
    if isinstance(payload, list):
        modules = payload
    else:
        modules = payload.get("moduller", [])
    if not isinstance(modules, list):
        raise ValueError("JSON yapisi gecersiz: moduller listesi bekleniyor.")
    return modules


def validate_modules(modules: List[Dict[str, Any]]) -> None:
    for idx, module in enumerate(modules, start=1):
        for key in ("sira", "baslik", "dosya_adi", "sayfalar"):
            if key not in module:
                raise ValueError(f"Modul #{idx} icin zorunlu alan eksik: {key}")
        if not isinstance(module.get("sayfalar"), list):
            raise ValueError(f"Modul #{idx} sayfalar listesi gecersiz.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Grammar JSON verisini Supabase'e yukler.")
    parser.add_argument(
        "--json-file",
        default="json_output/tum_gramer_modulleri.json",
        help="Yuklenecek JSON dosyasi",
    )
    parser.add_argument(
        "--mode",
        choices=("upsert", "replace"),
        default="upsert",
        help="upsert: veriyi birlestir, replace: once temizle sonra yukle",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Veritabanina yazmadan sadece ozet raporu uret.",
    )
    parser.add_argument(
        "--supabase-url",
        default="",
        help="Opsiyonel: SUPABASE_URL degerini komut satirindan gec.",
    )
    parser.add_argument(
        "--supabase-key",
        default="",
        help="Opsiyonel: SUPABASE_SERVICE_ROLE_KEY degerini komut satirindan gec.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    load_dotenv(dotenv_path=Path(".env"), override=True, encoding="utf-8-sig")

    def _get_env(name: str) -> str:
        # Windows'ta BOM ile yazilan .env dosyalarinda key ismi \ufeff ile gelebilir.
        return (os.getenv(name, "") or os.getenv(f"\ufeff{name}", "")).strip()

    url = (args.supabase_url or _get_env("SUPABASE_URL")).strip()
    key = (
        args.supabase_key
        or _get_env("SUPABASE_SERVICE_ROLE_KEY")
        or _get_env("SUPABASE_KEY")
    ).strip()

    if not args.dry_run:
        if not url:
            raise ValueError("SUPABASE_URL bulunamadi. .env veya --supabase-url kullanin.")
        if not key:
            raise ValueError(
                "SUPABASE_SERVICE_ROLE_KEY bulunamadi. .env veya --supabase-key kullanin."
            )
        if key.startswith("sb_publishable_"):
            raise ValueError(
                "Gecersiz key: sb_publishable_* yazma yetkisi vermez. "
                "Project Settings > API altindaki service_role key kullanin."
            )

    modules = load_modules(Path(args.json_file))
    validate_modules(modules)

    uploader = SupabaseUploader(url=url, key=key, dry_run=args.dry_run)
    summary = uploader.upload_modules(modules, mode=args.mode)

    print("=" * 60)
    print("SUPABASE UPLOAD OZETI")
    print("=" * 60)
    print(f"Mode          : {summary['mode']}")
    print(f"Dry run       : {summary['dry_run']}")
    print(f"Modul         : {summary['module_count']}")
    print(f"Sayfa         : {summary['page_count']}")
    print(f"Ornek         : {summary['example_count']}")
    print(f"Mini test     : {summary['test_count']}")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
