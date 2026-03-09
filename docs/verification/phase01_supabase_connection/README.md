# Faz 1 Supabase Baglanti Kanitlari

## Ozet
- Supabase proje ref'i: `qretfjzaolpdguggcqfg`
- Uygulanan migration seti: `001-024`
- Dogrulama ciktilari: `docs/verification/phase01_supabase_connection/verification.json`
- Kanit ekran goruntuleri bu klasordedir

## Manuel Test Giris Bilgileri
- Ortak sifre: `PassageTR#2026!`
- Ogrenci free: `phase1.free@passagetr.dev`
- Ogrenci pro: `phase1.pro@passagetr.dev`
- Admin: `phase1.admin@passagetr.dev`
- Developer: `phase1.developer@passagetr.dev`

## Manuel Test Yuzeyleri
- Student web: `http://127.0.0.1:8151/`
- Student profil: `http://127.0.0.1:8151/profile`
- Admin web: `http://127.0.0.1:8152/`
- Android APK: `apps/student_app/build/app/outputs/flutter-apk/app-debug.apk`

## Student App Test Akisi
1. `http://127.0.0.1:8151/profile` adresini ac.
2. `Giris Yap` butonuna bas.
3. Hazir test hesaplarindan birini sec veya e-posta/sifre alanlarini doldur.
4. `Giris Yap` ile seeded hesabi ac.
5. PRO test icin `phase1.pro@passagetr.dev` kullan.
6. Cikis ve yeniden baglanma icin profil ekranindaki `Yenile` ve `Cikis Yap` butonlarini kullan.

## Admin Console Test Akisi
1. `http://127.0.0.1:8152/` adresini ac.
2. Giris ekraninda varsayilan seeded admin hesabi on-dolu gelir.
3. `Admin girisi` ile dashboard'a gec.
4. `Claimleri yenile` ile claim refresh davranisini kontrol et.

## Kanit Dosyalari
- `android_student_app_home.png`
- `student_web_home.png`
- `student_web_profile.png`
- `web_anonymous_auth.png`
- `web_sign_out.png`
- `admin_console_login.png`

## Notlar
- `service_role` istemci tarafina yazilmadi.
- Seed hesaplari gelistirme/stage icindir; repo paylasimi veya public dagitim oncesi sifre rotate edilmelidir.
