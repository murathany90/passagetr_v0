# Supabase Readings Import (Faz 2)

Bu dokuman Faz 2 reading tablolari icin CSV import adimlarini tarif eder.

## Kapsam
- App ici import yok.
- Import islemi Supabase Dashboard uzerinden yapilir.
- CSV formati UTF-8 ve delimiter `;` olmalidir.
- Faz 2 import ergonomisi icin `pack_name` ve `passage_title` yardimci kolonlari kullanilir.

## On Kosul
1. `supabase/migrations/20260226_003_phase2_readings.sql` migration'i calisti.
2. `packs` tablosunda `YDS Set 001` kaydi var.

## Dosya 1: readings_passages.csv
Konum: `docs/readings_passages.csv`

Header:
`pack_name;title;level;tags_raw;Category`

Import hedefi: `reading_passages`
Mapping:
- `pack_name` -> `pack_name`
- `title` -> `title`
- `level` -> `level`
- `tags_raw` -> `tags_raw`
- `Category` -> `category`

Not:
- `reading_passages.pack_name` gecici import kolonudur.
- Faz 2'de pragmatik olarak tabloda kalabilir; istenirse ileride drop edilebilir.

## Dosya 2: readings_sentences.csv
Konum: `docs/readings_sentences.csv`

Header:
`passage_title;idx;sentence_en;sentence_tr`

Import hedefi: `reading_passage_sentences`
Mapping:
- `passage_title` -> `passage_title`
- `idx` -> `idx`
- `sentence_en` -> `sentence_en`
- `sentence_tr` -> `sentence_tr`

Not:
- `reading_passage_sentences.passage_title` gecici import kolonudur.
- Faz 2'de pragmatik olarak tabloda kalabilir; istenirse ileride drop edilebilir.

## Import Sirasi (Zorunlu)
1. Once `reading_passages` import edilir.
2. Sonra `reading_passage_sentences` import edilir.
3. Son olarak FK baglama SQL'leri calistirilir.

## Post-import SQL (FK Baglama)

```sql
update public.reading_passages rp
set pack_id = (
  select p.id
  from public.packs p
  where p.name = rp.pack_name
  limit 1
)
where rp.pack_id is null
  and rp.pack_name is not null;

update public.reading_passage_sentences s
set passage_id = (
  select p.id
  from public.reading_passages p
  where p.title = s.passage_title
  limit 1
)
where s.passage_id is null
  and s.passage_title is not null;
```

## Kontrol Query'leri

```sql
-- 1) Reading passage sayisi
select count(*) as passage_count from public.reading_passages;

-- 2) Reading sentence sayisi
select count(*) as sentence_count from public.reading_passage_sentences;

-- 3) pack_id null kalan passage var mi?
select count(*) as null_pack_id_count
from public.reading_passages
where pack_id is null;

-- 4) passage_id null kalan sentence var mi?
select count(*) as null_passage_id_count
from public.reading_passage_sentences
where passage_id is null;

-- 5) idx duplicate kontrolu
select passage_id, idx, count(*) as cnt
from public.reading_passage_sentences
group by passage_id, idx
having count(*) > 1
order by cnt desc;
```

## Translation Cache Guvenlik Notu
- `reading_sentence_translations` upsert anahtari:
  `(sentence_id, provider, target_lang)` (unique constraint)
- RLS:
  - SELECT: `anon`, `authenticated` -> `true`
  - INSERT/UPDATE: `authenticated` -> `auth.uid() is not null`

## Uygulama Davranisi (Ceviri)
- Ceviri API cagrisi sadece kullanici `Ceviriyi Goster` aksiyonuna bastiginda tetiklenir.
- `sentence_tr` doluysa API cagrisi yapilmaz.
- `sentence_tr` bossa once cache kontrol edilir, cache yoksa API cagrisi yapilir.

### Ceviri Config Ornekleri
- Libre (varsayilan):
  - `TRANSLATE_PROVIDER=libre`
  - `TRANSLATE_ENDPOINT=https://libretranslate.example.com`
  - Uygulama endpoint sonuna gerekirse `/translate` ekler.
- Google Cloud:
  - `TRANSLATE_PROVIDER=google`
  - `TRANSLATE_ENDPOINT=https://translation.googleapis.com/language/translate/v2`
  - `TRANSLATE_API_KEY=<google-api-key>`

### Translation Disabled Modu
- `TRANSLATE_ENDPOINT` bos ise ceviri devre disi kabul edilir.
- Bu durumda `Ceviriyi Goster` aksiyonunda kullaniciya
  `Ceviri yapilandirilmadi.` mesaji gosterilir.

## Data Quality Notlari
- `idx` integer olmalidir.
- `sentence_en` bos olamaz.
- `sentence_tr` bos olabilir.
- Alan icinde `;` varsa cift tirnak zorunludur.
- Alan icinde `"` varsa CSV escape `""` kullanilmalidir.
