# Static Content Pipeline v2

Bu dokuman words + readings + dictionary verisinin:

1. Supabase'e replace import edilmesini
2. Tek SQLite asset (`app_content.db`) uretilmesini

adim adim tarif eder.

## On Kosullar

1. Migration dosyalari push edilmis olmali.
2. `.env` icinde:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. Python bagimliliklari:
   - `python -m pip install -r requirements.txt`

## 1) Migration Push

```powershell
supabase db push
```

## 2) Supabase Static Content Import (replace)

```powershell
python .\scripts\import_static_content_supabase.py --words-file .\docs\YDS_Set_001.csv --passages-file .\docs\readings_passages.csv --sentences-file .\docs\readings_sentences.csv --mode replace --batch-size 1000 --report-file .\json_output\static_content_import_report.json
```

Bu script:

1. `admin_reset_static_content()` RPC ile eski statik veriyi temizler.
2. `packs` tablosunda CSV'de gecen pack adlarini upsert eder.
3. `words`, `reading_passages`, `reading_passage_sentences` tablolarini doldurur.
4. `readings_sentences.csv` icindeki tamamen bos satirlari skip eder.
5. `passage_title+idx` cakismasi varsa deterministic reindex uygular.
6. Deterministic UUID parity kontrolu yapar ve `id_parity_ok=true` bekler.

## 3) Tek Asset DB Uretimi

```powershell
python .\scripts\build_app_content_db.py --dictionary-xlsx .\docs\dictionary.xlsx --words-file .\docs\YDS_Set_001.csv --passages-file .\docs\readings_passages.csv --sentences-file .\docs\readings_sentences.csv --output-db .\assets\db\app_content.db --report-file .\json_output\app_content_build_report.json --dataset-version 2026-03-04-v2
```

Bu script:

1. Dictionary + words + readings verisini tek SQLite dosyasina yazar.
2. `dictionary_entries_fts` (FTS5) tablosunu rebuild eder.
3. `assets/db/app_content.meta.json` sidecar dosyasini olusturur.
4. Rapor ciktisini `json_output/app_content_build_report.json` olarak uretir.

## Dogrulama Checklist

1. `static_content_import_report.json`:
   - words loaded = 5314
   - passages loaded = 678
   - sentences loaded = 5242 (bos 16 satir skip)
   - id_parity_ok = true
2. Supabase SQL kontrol:
   - `select count(*) from words;`
   - `select count(*) from reading_passages;`
   - `select count(*) from reading_passage_sentences;`
   - `select count(*) from reading_passage_sentences group by passage_id, idx having count(*) > 1;` sonuc bos olmali.
3. `app_content_build_report.json`:
   - tablo sayilari source ile uyumlu olmali.
   - dictionary_fts_rows > 0 olmali.
