# Phase 10 P2 Backlog

Bu dosya, Faz 10 kapsam disinda tutulan ve sonraki sertlestirme turlerine birakilan `P2` maddeleri toplar.

## Kaynak
- `docs/reports/other_agent_product_improvement_suggestions.md`
- `docs/verification/other_agent_live_test/results.md`

## Kapsam Disi Birakilan Maddeler
1. Dark mode token derinlestirmesi
   Not: `AppThemeTokens` mevcut parity ihtiyacini karsiliyor, ancak dark mode renk hiyerarsisi Figma seviyesinde daha da detaylandirilabilir.
2. Admin oturum suresi ve session expiry hardening
   Not: `admin_console` giris ve route korumalari calisiyor, fakat token dususu ve session timeout davranisi ayrica sertlestirilecek.
3. Offline cache ve sync enhancement
   Not: Mevcut Faz 2 foundation korunuyor. IndexedDB/PWA cache ve daha agresif offline fallback bu backlog maddesidir.
4. Web performans ve loading polish
   Not: `flutter build web` bundle calisiyor, ancak `--wasm`, custom HTML loading shell ve ileri cache stratejileri sonraki turda ele alinacak.
5. Admin bulk action ve data table ergonomisi
   Not: Faz 5 kapsamindaki temel CMS calisiyor; toplu eylemler ve daha genis desktop veri tablolari sonraki iyilestirme turundadir.

## Oncelik Sirasi
1. Admin session expiry hardening
2. Dark mode token polish
3. Offline cache enhancement
4. Web performance polish
5. Admin bulk actions
