# Faz 0 - Kesif, Kurulum ve Teknik Iskelet

## 1. Faz Amaci
PASSAGETR v2 monorepo foundation'ini, workspace calisma duzenini ve iki uygulamali temel kabugu calisir hale getirmek.

## 2. Kapsam
- Monorepo workspace duzeltmeleri
- `apps/student_app` ve `apps/admin_console` temel shell yapisi
- `packages/shared_*` temel sorumluluklarinin acilmasi
- Faz 1'e gecis icin gerekli environment ve router iskeleti

## 3. Kapsam Disi
- Tam auth akisi
- Drift veri senkronizasyonu
- CMS CRUD ekranlari
- Icerik domainlerinin tam uygulamasi

## 4. Yapilacak Isler
- [x] Faz calisma dosyasini olustur
- [x] Mevcut foundation durumunu dokumante et
- [x] Tum workspace uyelerine `resolution: workspace` ekle
- [x] Ortak package export ve klasor yapisini faz kararlarina gore genislet
- [x] `student_app` ve `admin_console` bootstrap/router shell yapisini yeni mimariye tasit
- [x] Faz 0 cikis testlerini calistir ve sonucu kaydet

## 5. Teknik Kararlar
- Workspace topolojisi sabit: `apps/student_app`, `apps/admin_console`, `packages/shared_core`, `packages/shared_domain`, `packages/shared_data`, `packages/shared_ui`
- `main` v1 arsiv dali, aktif gelistirme `v2-rewrite-foundation`
- Faz 0 kapanmadan Faz 1 tam uygulamasina gecilmez; ancak Faz 1 iskeleti icin gerekli temel klasor ve sozlesmeler bu fazda acilabilir
- Web remote-first, Android offline-first kararini bozacak herhangi bir lokal asset/web entegrasyonu yapilmaz

## 6. Bagimliliklar
- Flutter workspace / pub workspaces
- Riverpod ve go_router
- Supabase migration baseline `001-013`

## 7. Riskler
- Workspace `resolution: workspace` eksikligi nedeniyle analyze/test su an calismiyor
- Shared package sorumluluklari acilmadan app kodu buyurse tekrar tek-app kok yapisina donus riski var

## 8. Test ve Kabul Kriterleri
- `flutter analyze apps/student_app` basarili olmali
- `flutter analyze apps/admin_console` basarili olmali
- `flutter test apps/student_app` basarili olmali
- `flutter test apps/admin_console` basarili olmali
- Iki uygulama da yeni bootstrap ve route shell ile acilabiliyor olmali

## 9. Ilerleme Durumu
- Durum: Tamamlandi
- Son guncelleme: 2026-03-08

## 10. Tamamlananlar / Notlar
- Monorepo root yapisi ve iki uygulamali temel scaffold mevcut
- `docs/phases` altinda bu faz icin ilk calisma dosyasi acildi
- Workspace `resolution: workspace` eksigi giderildi
- `shared_core`, `shared_domain`, `shared_data`, `shared_ui` icin temel export ve klasor iskeleti acildi
- `student_app` ve `admin_console` yeni bootstrap/router shell ile guncellendi
- `flutter analyze`, `flutter test apps/student_app` ve `flutter test apps/admin_console` 2026-03-08 tarihinde basarili calisti
- Paket temel testleri de eklendi: `flutter test packages/shared_core` ve `flutter test packages/shared_data`
