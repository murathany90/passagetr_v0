create table if not exists public.gramer_modulleri (
  id bigserial primary key,
  sira integer not null,
  baslik text not null,
  dosya_adi text not null,
  toplam_sayfa integer not null default 0,
  icon text not null default '📘',
  renk text not null default '#4776E6',
  created_at timestamptz not null default now()
);

create unique index if not exists ux_gramer_modulleri_sira
  on public.gramer_modulleri (sira);

create unique index if not exists ux_gramer_modulleri_dosya_adi
  on public.gramer_modulleri (dosya_adi);

create table if not exists public.gramer_sayfalari (
  id bigserial primary key,
  modul_id bigint not null references public.gramer_modulleri(id) on delete cascade,
  sayfa_no integer not null,
  baslik text not null,
  icerik_html text not null,
  kelime_sayisi integer not null default 0,
  created_at timestamptz not null default now(),
  unique (modul_id, sayfa_no)
);

create index if not exists ix_gramer_sayfalari_modul_id
  on public.gramer_sayfalari (modul_id);

create table if not exists public.gramer_ornekler (
  id bigserial primary key,
  sayfa_id bigint not null references public.gramer_sayfalari(id) on delete cascade,
  sira integer not null default 0,
  ingilizce text not null,
  turkce text not null,
  aciklama text,
  created_at timestamptz not null default now(),
  unique (sayfa_id, sira)
);

create index if not exists ix_gramer_ornekler_sayfa_id
  on public.gramer_ornekler (sayfa_id);

create table if not exists public.gramer_testler (
  id bigserial primary key,
  sayfa_id bigint not null references public.gramer_sayfalari(id) on delete cascade,
  sira integer not null default 0,
  soru text not null,
  secenekler_json jsonb not null default '{}'::jsonb,
  dogru_cevap text,
  aciklama text,
  created_at timestamptz not null default now(),
  unique (sayfa_id, sira)
);

create index if not exists ix_gramer_testler_sayfa_id
  on public.gramer_testler (sayfa_id);

alter table public.gramer_modulleri enable row level security;
alter table public.gramer_sayfalari enable row level security;
alter table public.gramer_ornekler enable row level security;
alter table public.gramer_testler enable row level security;

grant select on table public.gramer_modulleri to anon, authenticated;
grant select on table public.gramer_sayfalari to anon, authenticated;
grant select on table public.gramer_ornekler to anon, authenticated;
grant select on table public.gramer_testler to anon, authenticated;

drop policy if exists gramer_modulleri_select_all on public.gramer_modulleri;
create policy gramer_modulleri_select_all on public.gramer_modulleri
for select
to anon, authenticated
using (true);

drop policy if exists gramer_sayfalari_select_all on public.gramer_sayfalari;
create policy gramer_sayfalari_select_all on public.gramer_sayfalari
for select
to anon, authenticated
using (true);

drop policy if exists gramer_ornekler_select_all on public.gramer_ornekler;
create policy gramer_ornekler_select_all on public.gramer_ornekler
for select
to anon, authenticated
using (true);

drop policy if exists gramer_testler_select_all on public.gramer_testler;
create policy gramer_testler_select_all on public.gramer_testler
for select
to anon, authenticated
using (true);

