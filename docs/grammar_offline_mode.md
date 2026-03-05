# Gramer Offline Modu (Hibrit + Local-first)

## Amaç
- Gramer sekmesi internet olmadan da açılabilsin.
- Uygulama ilk kaynaktan lokal `app_content.db` kullansın.
- Ağ varsa Supabase üzerinden arka plan güncellemesi yapılabilsin.

## Mimari
1. `app_content.db` içine grammar tabloları eklenir:
   - `grammar_modules`
   - `grammar_pages`
   - `grammar_examples`
   - `grammar_tests`
2. `HybridGrammarRepository` local-first çalışır:
   - Önce lokalden okur.
   - Lokal boşsa Supabase’den çekip locale yazar.
   - Sync hatasında lokal içerik varsa UI devam eder.
3. `GrammarHomePage` arka planda non-blocking `syncIfStale()` çağırır.

## Fallback Matrisi
| Durum | Lokal Veri | Ağ | Davranış |
|---|---|---|---|
| Normal offline kullanım | Var | Yok | Lokal içerik açılır |
| İlk kurulum + internet var | Yok | Var | Remote çekilir, locale yazılır, UI açılır |
| İlk kurulum + internet yok | Yok | Yok | “Lokal içerik yok” hatası |
| Lokal var + remote hata | Var | Sorunlu | Lokal içerik kullanılmaya devam eder |

## Build Pipeline
Gramer içeriklerini `app_content.db` içine gömmek için:

```bash
python markdown_to_json_converter.py --input-dir docs/gramer --output-dir json_output
python scripts/build_app_content_db.py \
  --dictionary-xlsx docs/dictionary.xlsx \
  --words-file docs/YDS_Set_001.csv \
  --passages-file docs/readings_passages.csv \
  --sentences-file docs/readings_sentences.csv \
  --grammar-dir docs/gramer \
  --output-db assets/db/app_content.db \
  --report-file json_output/app_content_build_report.json
```

## Troubleshooting
1. `Lokal içerik yok`:
   - `assets/db/app_content.db` güncel değil.
   - Build script’i tekrar çalıştırın ve uygulamayı yeniden kurun.
2. `Güncelleme alınamadı`:
   - Supabase ağ/erişim sorunu.
   - Lokal içerik varsa kullanım devam eder.
3. Eski cihaz veritabanı:
   - Drift şema upgrade grammar tablolarını oluşturur.
   - İçerik yoksa bir kez online açılış veya yeni asset gerekir.
