# PASSAGETR v2

PASSAGETR v2, v1 uygulamasinin kontrollu yeniden yazim reposudur.

## Durum

- `main`: v1 arsiv durumu
- `v2-rewrite-foundation`: aktif v2 foundation dali
- Mimari: Android offline-first, Web remote-first
- Repo modeli: ayni monorepo icinde `student_app` ve `admin_console`

## Workspace

```text
apps/
  student_app/
  admin_console/
packages/
  shared_core/
  shared_domain/
  shared_data/
  shared_ui/
assets/
docs/
scripts/
supabase/
```

## Korunan Alanlar

- `docs/`
- `DATABASE_SCHEMA.md`
- `supabase/`
- `assets/`
- `scripts/`
- `env/*.example`

## Ilk Hedef

v2 foundation asamasinda hedef; temiz monorepo iskeleti, ortak paket yapisi, student/admin ayri app girisleri ve migration-first veri evrim altyapisini kurmaktir.

## Dokumanlar

- Yol haritasi: `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
- Agent prompt: `docs/prompt.md`
- v1 arsiv dokumanlari: `docs/archive/v1/`
- v1 veri modeli: `DATABASE_SCHEMA.md`
