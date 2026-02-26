# Supabase CSV Import (Faz 1)

## Kapsam
- App ici import yok.
- CSV import yalniz Supabase Dashboard uzerinden yapilir.
- Faz 1 veri dosyasi: `docs/YDS_Set_001.csv`.

## CSV Formati
- Delimiter: `;`
- Quote char: `"`
- Encoding: `UTF-8`
- First row is header: acik

Header:
`en_word;tr_meaning;pos;example_en;example_tr;synonyms;antonyms;level;tags;notes`

## Bu Projedeki CSV Dogrulama Ozeti
- Dosya: `docs/YDS_Set_001.csv`
- Toplam satir (header dahil): `235`
- Veri satiri: `234`
- Header kolon sayisi: `10`
- Gozlenen `pos` degerleri: `adj, adv, det, noun, prep, verb`
- Quote kontrolu: bozuk/tek kalan cift tirnak satiri bulunmadi.
- Parser kontrolu: tum satirlar 10 kolona temiz parse edildi.

## Import Mapping
- `en_word` -> `en_word`
- `tr_meaning` -> `tr_meaning`
- `pos` -> `pos`
- `example_en` -> `example_en`
- `example_tr` -> `example_tr`
- `synonyms` -> `synonyms_raw`
- `antonyms` -> `antonyms_raw`
- `level` -> `level`
- `tags` -> `tags_raw`
- `notes` -> `notes`

## Ornek CSV
en_word;tr_meaning;pos;example_en;example_tr;synonyms;antonyms;level;tags;notes
abandon;terk etmek;verb;He abandoned the plan.;Plani terk etti.;"leave; desert";"keep; continue";B2;;
ability;yetenek;noun;She has the ability to sing.;Sarki soyleme yetenegi var.;"capability; talent";inability;B1;;
abroad;yurt disi;adv;He lives abroad.;Yurt disinda yasiyor.;overseas;locally;A2;;
absent;mevcut olmayan;adj;He was absent from school.;Okulda yoktu.;"missing; away";present;B1;;

## Data Quality Kurallari
- Bir field icinde `;` geciyorsa field cift tirnak icinde olmali.
- Bir field icinde `"` geciyorsa CSV escape kuraliyla `""` kullanilmali.
- Bos opsiyonel alanlar bos birakilabilir.

## Dashboard Import Ayari (Birebir)
1. Supabase Dashboard -> Table Editor -> `words` -> Import data (CSV).
2. Delimiter: `;`
3. Quote char: `"`
4. First row is header: Acik
5. Encoding: `UTF-8`
6. Mapping:
   - `synonyms` -> `synonyms_raw`
   - `antonyms` -> `antonyms_raw`
   - `tags` -> `tags_raw`
   - diger kolonlar birebir isim eslesmesi.

## Pack Stratejisi (Faz 1 Default)
1. `packs` tablosunda `YDS Set 001` olmali.
2. CSV import sonrasi:
`UPDATE words SET pack_id = (SELECT id FROM packs WHERE name='YDS Set 001' LIMIT 1) WHERE pack_id IS NULL;`
3. CSV'de `pack_id` kolonunu vermek opsiyoneldir (gelecek uyumluluk).

## Import Sonrasi Hemen Calistirilacak Kontroller
- `docs/sql/phase1_post_import_checks.sql` dosyasindaki queryleri calistirin.
