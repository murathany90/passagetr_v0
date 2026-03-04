# Dictionary Foundation Faz 1

Bu dokuman 120k EN-TR sozluk altyapisinin Faz 1 implementasyonunu tarif eder.

## Kapsam
- Supabase dictionary tablolari + RLS
- Excel -> Supabase import script
- Flutter tarafinda Drift/SQLite local dictionary cache
- Local-first lookup + DeepL edge fallback

## Migration
- Dosya: `supabase/migrations/202603030006_dictionary_foundation.sql`
- Eklenenler:
  - `dictionary_entries`
  - `dictionary_import_batches`
  - `dictionary_fallback_cache`
  - `dictionary_missing_queries`
  - `dictionary_bootstrap_manifest()`
  - `dictionary_entries_bootstrap_page()`

## Import
- Script: `scripts/import_dictionary.py`
- Ornek:

```bash
python scripts/import_dictionary.py \
  --excel-file docs/dictionary.xlsx \
  --sheet Sheet1 \
  --mode replace \
  --dataset-version 2026-03-03-v1 \
  --batch-size 1000 \
  --report-file json_output/dictionary_import_report.json
```

## Flutter
- Local DB: Drift/SQLite
- Repository: `OfflineDictionaryRepository`
- Bootstrap: `appBootstrapProvider` auth + dictionary init
- Lookup sirasi:
  1. local dictionary
  2. server fallback cache
  3. DeepL edge function
  4. local/server cache write

## Notlar
- DeepL key client'a konmaz, edge function uzerinden calisir.
- Service role key sadece import script tarafinda kullanilir.
- Dictionary bootstrap resume desteklidir (`last_seq_id`).
