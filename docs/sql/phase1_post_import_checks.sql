-- Faz 1 post-import kontrol sorgulari
-- Beklenen CSV: docs/YDS_Set_001.csv

-- 1) Toplam kelime sayisi
select count(*) as total_words
from public.words;

-- 2) pack_id null kalan satirlar
select count(*) as null_pack_id_count
from public.words
where pack_id is null;

-- 3) Master pack altindaki satir sayisi
select p.name, count(w.id) as word_count
from public.packs p
left join public.words w on w.pack_id = p.id
group by p.name
order by p.name;

-- 4) Duplicate kontrolu (UNIQUE(pack_id, en_word, pos) disinda kalan olasi veri)
select pack_id, en_word, pos, count(*) as cnt
from public.words
group by pack_id, en_word, pos
having count(*) > 1
order by cnt desc, en_word asc;

-- 5) pos dagilimi
select pos, count(*) as cnt
from public.words
group by pos
order by pos;

-- 6) pos enum disi deger kontrolu
select id, en_word, pos
from public.words
where pos not in ('noun','verb','adj','adv','prep','conj','pron','det','phrasal','idiom','other')
order by en_word;

-- 7) Synonym/antonym/tag ham veri hizli ornek
select id, en_word, synonyms_raw, antonyms_raw, tags_raw
from public.words
order by created_at desc
limit 20;

-- 8) Progress tablo genel durum
select
  count(*) as total_progress_rows,
  count(distinct user_id) as distinct_users,
  count(distinct word_id) as distinct_words,
  min(mastery) as min_mastery,
  max(mastery) as max_mastery
from public.user_word_progress;

-- 9) Mastery clamp ihlali kontrolu
select *
from public.user_word_progress
where mastery < 0 or mastery > 100
limit 50;

-- 10) Ornek kullanici progress detay
-- uuid degerini ihtiyaca gore degistirin.
-- select * from public.user_word_progress where user_id = '00000000-0000-0000-0000-000000000000'::uuid limit 100;
