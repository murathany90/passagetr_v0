# Release Freeze - 2026-03-09

## Freeze Kapsami
- Baseline migration seti: `001-013`
- Rewrite migration seti: `014-028`
- Freeze sonrasi yeni feature migration'i eklenmeden once bu dosya guncellenecek

## Onaylanan Artifact'lar
- Student web release bundle
- Admin web release bundle
- Student Android release APK

## Rollback Notu
- Supabase rollback noktasi: `202603090028_user_daily_stats_analytics_helpers.sql` oncesi remote migration seviyesi
- Uygulama rollback'i icin once onceki web bundle deploy edilir, sonra Android tarafinda onceki imzali release dagitilir

## Preflight Sonucu
- `scripts/release_preflight.ps1` basarili
- Auth smoke basarili
- Responsive smoke basarili
- Firebase hosting readiness basarili
