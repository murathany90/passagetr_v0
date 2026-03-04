# Prebuilt Dictionary Asset (Excel -> SQLite -> Flutter)

Bu dokuman 120k sozluk verisini uygulamanin icine `assets/db/dictionary_local.sqlite` olarak gommek icin kullanilir.

## 1) Asset DB uret

```powershell
python .\scripts\build_dictionary_asset.py --excel-file .\docs\dictionary.xlsx --sheet Sheet1 --dataset-version 2026-03-03-v1 --output-db .\assets\db\dictionary_local.sqlite --report-file .\json_output\dictionary_asset_build_report.json
```

- `sheet` ismi farkliysa script otomatik tek sheet fallback yapar.
- Script duplicate/invalid/empty meaning satirlarini raporlar.

## 2) Flutter tarafi

- `pubspec.yaml` icinde asset tanimi vardir:
  - `assets/db/dictionary_local.sqlite`
- Uygulama ilk acilista bu dosyayi cihazin yazilabilir alanina kopyalar.
- Dosya zaten varsa tekrar kopyalanmaz.

## 3) Runtime davranisi

- Local DB `ready` ise uygulama startup'ta ag beklemez.
- Dictionary lookup local-first calisir.
- Sonuc yoksa fallback sirasiyla:
  1. server fallback cache
  2. DeepL edge function
  3. local/server cache write

## 4) Opsiyonel Supabase import

Prebuilt DB kullansaniz bile sunucu tarafi analytics/fallback/delta icin import scripti calistirabilirsiniz:

```powershell
python .\scripts\import_dictionary.py --excel-file .\docs\dictionary.xlsx --sheet Sheet1 --mode replace --dataset-version 2026-03-03-v1 --batch-size 1000 --report-file .\json_output\dictionary_import_report.json
```
