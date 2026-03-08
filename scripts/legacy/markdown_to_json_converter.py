"""
Markdown -> JSON converter for grammar lesson files.

This script parses markdown files under docs/gramer and emits JSON payloads
compatible with Supabase uploader and local app_content.db builder.
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import markdown as md


TITLE_MAP: Dict[str, str] = {
    "01_temel_kavramlar.md": "İngilizcede Temel Kavramlar",
    "02_tense_system.md": "Tense System in English (İngilizcede Zamanlar)",
    "03_modality.md": "Modality (Modal Fiiller)",
    "04_passive_causatives.md": "Passive Voice and Causatives (Edilgen Yapı ve Ettirgenler)",
    "05_gerunds_infinitives.md": "Gerunds and Infinitives (İsim Fiiller ve Mastarlar)",
    "06_adjectives_adverbs.md": "Adjectives and Adverbs (Sıfatlar ve Zarflar)",
    "07_adjective_clauses.md": "Adjective Clauses (Sıfat Yan Cümlecikleri)",
    "08_noun_clauses.md": "Noun Clauses (İsim Yan Cümlecikleri)",
    "09_conditionals.md": "Conditionals and If Clauses (Koşul Cümleleri)",
    "10_conjunctions.md": "Conjunctions and Adverbial Clauses (Bağlaçlar ve Zarf Cümlecikleri)",
    "11_determiners.md": "Determiners and Quantifiers (Belirleyiciler ve Miktar Belirten Sözcükler)",
    "12_review_tests.md": "Gramer Tekrar ve Testler",
}

ICON_MAP: Dict[int, str] = {
    1: "🔤",
    2: "⏰",
    3: "⚡",
    4: "🔁",
    5: "📝",
    6: "🎨",
    7: "🏷️",
    8: "💬",
    9: "🤔",
    10: "🔗",
    11: "🔢",
    12: "✅",
}

COLOR_MAP: Dict[int, str] = {
    1: "#4776E6",
    2: "#8E54E9",
    3: "#E44D26",
    4: "#2ECC71",
    5: "#F39C12",
    6: "#E67E22",
    7: "#3498DB",
    8: "#9B59B6",
    9: "#1ABC9C",
    10: "#E74C3C",
    11: "#34495E",
    12: "#F1C40F",
}


@dataclass
class ConversionWarning:
    file_name: str
    message: str
    page_number: Optional[int] = None

    def as_dict(self) -> Dict[str, Any]:
        return {
            "file_name": self.file_name,
            "page_number": self.page_number,
            "message": self.message,
        }


class MarkdownToJsonConverter:
    def __init__(self, input_dir: str = "docs/gramer", output_dir: str = "json_output") -> None:
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.warnings: List[ConversionWarning] = []

    def build_modules(self) -> List[Dict[str, Any]]:
        md_files = sorted(self.input_dir.glob("*.md"), key=self._sort_key)
        if not md_files:
            raise FileNotFoundError(f"Markdown dosyası bulunamadı: {self.input_dir}")

        modules: List[Dict[str, Any]] = []
        for index, md_file in enumerate(md_files, start=1):
            parsed = self.parse_markdown_file(md_file)
            pages = parsed["pages"]
            metadata = parsed["metadata"]
            modules.append(
                {
                    "sira": index,
                    "baslik": self.get_module_title(md_file.name),
                    "dosya_adi": md_file.name,
                    "toplam_sayfa": self.resolve_total_pages(metadata, pages),
                    "icon": ICON_MAP.get(index, "📘"),
                    "renk": COLOR_MAP.get(index, "#4776E6"),
                    "sayfalar": pages,
                }
            )
        return modules

    def convert_all(self) -> Dict[str, Any]:
        modules = self.build_modules()
        total_pages = sum(len(module.get("sayfalar", [])) for module in modules)
        total_examples = sum(
            len(page.get("examples", []))
            for module in modules
            for page in module.get("sayfalar", [])
        )
        total_tests = sum(
            len(page.get("mini_tests", []))
            for module in modules
            for page in module.get("sayfalar", [])
        )

        for module in modules:
            module_path = self.output_dir / f"modul_{int(module['sira']):02d}.json"
            self.write_json(module_path, module)

        combined = {"moduller": modules}
        self.write_json(self.output_dir / "tum_gramer_modulleri.json", combined)

        report = {
            "created_at_utc": datetime.now(timezone.utc).isoformat(),
            "input_dir": str(self.input_dir),
            "output_dir": str(self.output_dir),
            "module_count": len(modules),
            "page_count": total_pages,
            "example_count": total_examples,
            "test_count": total_tests,
            "warnings": [warning.as_dict() for warning in self.warnings],
        }
        self.write_json(self.output_dir / "conversion_report.json", report)
        return report

    def parse_markdown_file(self, file_path: Path) -> Dict[str, Any]:
        content = file_path.read_text(encoding="utf-8", errors="replace")
        metadata = self.extract_metadata(content, file_path.name)
        pages = self.extract_pages(content, file_path.name, metadata)
        if not pages:
            self.warn(file_path.name, "Sayfa marker bulunamadı, fallback parse kullanıldı.")
        return {
            "file_name": file_path.name,
            "metadata": metadata,
            "pages": pages,
        }

    def extract_metadata(self, content: str, file_name: str) -> Dict[str, str]:
        lines = content.splitlines()
        metadata_start = None
        for idx, line in enumerate(lines):
            if re.match(r"^##\s+.*METADATA\s*$", line.strip(), flags=re.IGNORECASE):
                metadata_start = idx + 1
                break

        if metadata_start is None:
            self.warn(file_name, "METADATA bölümü bulunamadı.")
            return {}

        metadata: Dict[str, str] = {}
        for line in lines[metadata_start:]:
            stripped = line.strip()
            if stripped == "---":
                break
            if not stripped:
                continue
            if stripped.startswith("#"):
                break
            item = re.match(r"^[-*]\s*(.+?):\s*(.+?)\s*$", stripped)
            if item:
                key = item.group(1).strip()
                value = item.group(2).strip()
                metadata[key] = value
        return metadata

    def extract_pages(
        self,
        content: str,
        file_name: str,
        metadata: Dict[str, str],
    ) -> List[Dict[str, Any]]:
        marker_pattern = re.compile(r"(?m)^##\s+.*SAYFA\s+(\d+)\s*$")
        matches = list(marker_pattern.finditer(content))

        pages: List[Dict[str, Any]] = []
        if matches:
            for idx, match in enumerate(matches):
                start = match.start()
                end = matches[idx + 1].start() if idx + 1 < len(matches) else len(content)
                chunk = content[start:end].strip()
                marker_page_no = self.parse_int(match.group(1), default=idx + 1)
                pages.append(self.parse_page(chunk, marker_page_no, file_name, metadata))
        else:
            chunks = [chunk.strip() for chunk in content.split("\n---\n") if chunk.strip()]
            for idx, chunk in enumerate(chunks, start=1):
                if "SAYFA" not in chunk and "| Sayfa " not in chunk:
                    continue
                pages.append(self.parse_page(chunk, idx, file_name, metadata))

        declared = self.parse_int(metadata.get("Toplam Sayfa"), default=0)
        if declared and declared != len(pages):
            self.warn(
                file_name,
                f"Metadata Toplam Sayfa={declared}, parse edilen sayfa={len(pages)}.",
            )
        return pages

    def parse_page(
        self,
        page_content: str,
        marker_page_no: int,
        file_name: str,
        metadata: Dict[str, str],
    ) -> Dict[str, Any]:
        lines = page_content.splitlines()
        if not lines:
            return {
                "page_number": marker_page_no,
                "title": f"Sayfa {marker_page_no}",
                "total_pages": self.parse_int(metadata.get("Toplam Sayfa"), default=0),
                "content_html": "",
                "examples": [],
                "mini_test": {},
                "mini_tests": [],
                "word_count": 0,
            }

        page_title_line_idx = None
        for idx, line in enumerate(lines):
            if line.strip().startswith("# "):
                page_title_line_idx = idx
                break

        title = f"Sayfa {marker_page_no}"
        current_page = marker_page_no
        total_pages = self.parse_int(metadata.get("Toplam Sayfa"), default=0)

        if page_title_line_idx is not None:
            title_line = lines[page_title_line_idx].strip()
            title_match = re.match(r"^#\s+(.*?)\s*(?:\|\s*Sayfa\s+(\d+)\s*/\s*(\d+))?\s*$", title_line)
            if title_match:
                title = title_match.group(1).strip()
                if title_match.group(2):
                    current_page = self.parse_int(title_match.group(2), default=current_page)
                if title_match.group(3):
                    total_pages = self.parse_int(title_match.group(3), default=total_pages)
            else:
                title = title_line.lstrip("#").strip()

        body_start = (page_title_line_idx + 1) if page_title_line_idx is not None else 1
        body_lines = self.strip_page_footer_lines(lines[body_start:])
        body_markdown = "\n".join(body_lines).strip()

        examples = self.extract_examples(body_markdown)
        mini_tests = self.extract_mini_tests(body_markdown)

        return {
            "page_number": current_page,
            "title": title,
            "total_pages": total_pages,
            "content_html": self.convert_to_html(body_markdown),
            "examples": examples,
            "mini_test": mini_tests[0] if mini_tests else {},
            "mini_tests": mini_tests,
            "word_count": self.count_words(body_markdown),
        }

    def extract_examples(self, content: str) -> List[Dict[str, str]]:
        pattern = re.compile(
            r"\*\*EN:\*\*\s*(.+?)\n\*\*TR:\*\*\s*(.+?)(?:\n(?:→|->)\s*\*\*Açıklama:\*\*\s*(.+?))?(?=\n\*\*EN:\*\*|\n##\s|\n---\n|$)",
            flags=re.DOTALL,
        )
        examples: List[Dict[str, str]] = []
        for match in pattern.finditer(content):
            en = self.clean_text(match.group(1))
            tr = self.clean_text(match.group(2))
            description = self.clean_text(match.group(3) or "")
            if en and tr:
                examples.append({"en": en, "tr": tr, "description": description})
        return examples

    def extract_mini_tests(self, content: str) -> List[Dict[str, Any]]:
        section_lines = content.splitlines()
        blocks: List[str] = []

        in_test_block = False
        current: List[str] = []
        for line in section_lines:
            is_heading = line.startswith("## ")
            heading_upper = line.upper()
            if is_heading and ("KENDİNİ TEST ET" in heading_upper or "TARAMA TEST" in heading_upper):
                if current:
                    blocks.append("\n".join(current))
                    current = []
                in_test_block = True
                current.append(line)
                continue
            if is_heading and in_test_block:
                blocks.append("\n".join(current))
                current = []
                in_test_block = False
            if in_test_block:
                current.append(line)
        if current:
            blocks.append("\n".join(current))

        tests: List[Dict[str, Any]] = []
        for block in blocks:
            sub_blocks = self.split_test_questions(block)
            if not sub_blocks:
                sub_blocks = [block]
            for sub_block in sub_blocks:
                test = self.parse_test_block(sub_block)
                if test:
                    tests.append(test)
        return tests

    def split_test_questions(self, block: str) -> List[str]:
        pattern = re.compile(r"(?m)^(?:\*\*Soru:\*\*|###\s*Soru\s+\d+\s*:)\s*")
        matches = list(pattern.finditer(block))
        if not matches:
            return []
        chunks: List[str] = []
        for idx, match in enumerate(matches):
            start = match.start()
            end = matches[idx + 1].start() if idx + 1 < len(matches) else len(block)
            chunk = block[start:end].strip()
            if chunk:
                chunks.append(chunk)
        return chunks

    def parse_test_block(self, block: str) -> Dict[str, Any]:
        question = ""
        options: Dict[str, str] = {}
        correct = ""
        explanation = ""

        q_match = re.search(
            r"\*\*Soru:\*\*\s*(.+?)(?=\n[A-E]\)|\n<details>|\n\*\*Doğru(?: Cevap)?:\*\*|$)",
            block,
            re.DOTALL,
        )
        if not q_match:
            q_match = re.search(
                r"###\s*Soru\s*\d+\s*:\s*\n\s*(.+?)(?=\n[A-E]\)|\n<details>|\n\*\*Doğru(?: Cevap)?:\*\*|$)",
                block,
                re.DOTALL,
            )
        if q_match:
            question = self.clean_text(q_match.group(1))

        option_pattern = re.compile(
            r"^\s*([A-E])\)\s*(.+?)(?=^\s*[A-E]\)\s*|^\s*<details>|^\s*\*\*Doğru(?: Cevap)?:\*\*|^\s*---\s*$|\Z)",
            flags=re.MULTILINE | re.DOTALL,
        )
        for match in option_pattern.finditer(block):
            key = match.group(1).strip().upper()
            value = self.clean_text(match.group(2))
            if value:
                options[key] = value

        correct_match = re.search(r"\*\*Doğru Cevap:\*\*\s*(.+?)(?=\n|$)", block, re.DOTALL)
        if not correct_match:
            correct_match = re.search(r"\*\*Doğru:\*\*\s*(.+?)(?=\n|$)", block, re.DOTALL)
        if correct_match:
            correct = self.clean_text(correct_match.group(1))

        explanation_match = re.search(
            r"\*\*Açıklama:\*\*\s*(.+?)(?=\n</details>|\n###\s+Soru|\n##\s|\n---\s*$|\Z)",
            block,
            re.DOTALL | re.MULTILINE,
        )
        if explanation_match:
            explanation = self.clean_text(explanation_match.group(1))

        if not question and not options and not correct and not explanation:
            return {}

        return {
            "question": question,
            "options": options,
            "correct": correct,
            "explanation": explanation,
        }

    def strip_page_footer_lines(self, body_lines: List[str]) -> List[str]:
        lines = list(body_lines)
        footer_patterns = [
            r"^\s*###\s+.*Sonraki",
            r"^\s*###\s+.*B[öo]l[üu]m",
            r"^\s*###\s+.*İlerleme",
            r"^\s*###\s+.*Ilerleme",
        ]

        removed_footer = False
        while lines:
            tail = lines[-1].strip()
            if not tail:
                lines.pop()
                continue
            if any(re.search(pattern, lines[-1], flags=re.IGNORECASE) for pattern in footer_patterns):
                removed_footer = True
                lines.pop()
                continue
            if removed_footer and tail == "---":
                lines.pop()
                continue
            break
        return lines

    def convert_to_html(self, markdown_content: str) -> str:
        if not markdown_content.strip():
            return ""
        return md.markdown(
            markdown_content,
            extensions=[
                "extra",
                "tables",
                "fenced_code",
                "sane_lists",
                "nl2br",
            ],
            output_format="html5",
        )

    def resolve_total_pages(self, metadata: Dict[str, str], pages: List[Dict[str, Any]]) -> int:
        declared = self.parse_int(metadata.get("Toplam Sayfa"), default=0)
        if declared:
            return declared
        if not pages:
            return 0
        totals = [self.parse_int(page.get("total_pages"), default=0) for page in pages]
        totals = [value for value in totals if value > 0]
        if totals:
            return max(totals)
        return len(pages)

    def get_module_title(self, filename: str) -> str:
        return TITLE_MAP.get(filename, filename.replace(".md", "").replace("_", " ").title())

    def write_json(self, path: Path, data: Any) -> None:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def clean_text(self, text: str) -> str:
        compact = re.sub(r"[ \t]+", " ", text or "")
        compact = re.sub(r"\n{3,}", "\n\n", compact)
        return compact.strip()

    def count_words(self, text: str) -> int:
        return len(re.findall(r"[A-Za-z0-9À-ÿİıŞşĞğÇçÖöÜü]+(?:'[A-Za-z]+)?", text))

    def parse_int(self, value: Any, default: int = 0) -> int:
        if value is None:
            return default
        match = re.search(r"\d+", str(value))
        if not match:
            return default
        try:
            return int(match.group(0))
        except ValueError:
            return default

    def warn(self, file_name: str, message: str, page_number: Optional[int] = None) -> None:
        self.warnings.append(
            ConversionWarning(
                file_name=file_name,
                page_number=page_number,
                message=message,
            )
        )

    def _sort_key(self, path: Path) -> tuple[int, str]:
        prefix_match = re.match(r"^(\d+)", path.name)
        if prefix_match:
            return (int(prefix_match.group(1)), path.name)
        return (9999, path.name)


def load_grammar_modules_from_markdown(input_dir: str | Path = "docs/gramer") -> List[Dict[str, Any]]:
    converter = MarkdownToJsonConverter(input_dir=str(input_dir))
    return converter.build_modules()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Markdown dosyalarını JSON'a dönüştürür.")
    parser.add_argument(
        "--input-dir",
        default="docs/gramer",
        help="Markdown dosyalarının bulunduğu klasör (varsayılan: docs/gramer)",
    )
    parser.add_argument(
        "--output-dir",
        default="json_output",
        help="JSON çıktı klasörü (varsayılan: json_output)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Warning varsa exit code 2 ile çık.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    converter = MarkdownToJsonConverter(input_dir=args.input_dir, output_dir=args.output_dir)
    report = converter.convert_all()

    print("=" * 60)
    print("MARKDOWN -> JSON DÖNÜŞÜM TAMAMLANDI")
    print("=" * 60)
    print(f"Modül sayısı      : {report['module_count']}")
    print(f"Sayfa sayısı      : {report['page_count']}")
    print(f"Örnek sayısı      : {report['example_count']}")
    print(f"Mini test sayısı  : {report['test_count']}")
    print(f"Warning sayısı    : {len(report['warnings'])}")
    print(f"Çıktı klasörü     : {args.output_dir}")
    print("=" * 60)

    if args.strict and report["warnings"]:
        print("Strict mod: warning bulunduğu için hata kodu dönülüyor.")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
