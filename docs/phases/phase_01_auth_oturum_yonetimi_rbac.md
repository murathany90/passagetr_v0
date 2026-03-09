# Faz 1 - Auth, Oturum Yonetimi ve RBAC

## 1. Faz Amaci
Supabase tabanli auth, rol/plan modeli ve route/RLS guvenlik omurgasini kontrollu rewrite mimarisine baglamak ve dogrulamak.

## 2. Kapsam
- Supabase auth entegrasyonu
- Anonim oturum, e-posta/sifre girisi ve kayit
- Anonim hesabi kayitli hesaba yukseltme
- `profiles`, `user_roles`, `entitlements` ve ilgili helper migration'lari
- `authGuard`, `premiumGate`, `adminGuard`
- `student_app` ve `admin_console` icin manuel test yuzeyi

## 3. Kapsam Disi
- Offline sync motorunun tam implementasyonu
- CMS mutasyon ekranlarinin tamamlanmasi
- Analytics, streak ve hedef modulleri

## 4. Yapilacak Isler
- [x] Faz calisma dosyasini olustur
- [x] `014_profiles_user_roles_entitlements.sql` migration'ini ekle
- [x] `015_auth_claim_helpers_rbac.sql` migration'ini ekle
- [x] `016_content_access_flags.sql` migration'ini ekle
- [x] `017-023` Faz 1'i destekleyen migration setini ekle
- [x] `024_auth_helper_security_definer.sql` ile RLS recursion hatasini duzelt
- [x] Supabase project baglantisini kur ve repo'yu projeye linkle
- [x] Uzak veritabanina `001-024` migration setini uygula
- [x] `student_app` icin auth, premium ve admin guard akisini ac
- [x] `admin_console` icin korumali giris shell'ini ac
- [x] Gercek Supabase env ile web auth smoke scriptini calistir
- [x] Stage test hesaplarini seed et ve rol/plan/RLS sonucunu kaydet
- [x] `student_app` profilinde seeded hesaplarla manuel giris yuzeyi ac
- [x] Faz 1 cikis testlerini calistir ve sonucu kaydet

## 5. Teknik Kararlar
- Rol modeli sabit: `user`, `admin`, `developer`
- Plan modeli sabit: `free`, `pro`
- JWT claim anahtarlari sabit: `app_role`, `plan`
- `service_role` istemciye tasinmaz; sadece CLI/seed script seviyesinde kullanilir
- `current_app_role`, `current_plan`, `is_admin_or_developer`, `is_developer` helper fonksiyonlari `security definer` olarak calisir
- `student_app` icinde gorunur auth erisim modal'i bulunur; dev panel sadece `admin` veya `developer` oturumlarinda gorunur

## 6. Bagimliliklar
- Faz 0 workspace duzeltmeleri
- Supabase Auth
- Baseline migration'lar `001-013`
- Rewrite migration seti `014-024`

## 7. Riskler
- Claim refresh gecikmesi UI gorunurlugunu geciktirebilir
- Yanlis yazilmis RLS helper fonksiyonlari recursive policy cagrisina yol acabilir
- Seed hesaplari repoda paylasilacaksa sifreler daha sonra rotate edilmelidir

## 8. Test ve Kabul Kriterleri
- Yeni kullanici varsayilan `user` + `free` atamasi alir
- Anonim kullanici verisini kaybetmeden kayitli hesaba yukselebilir
- `admin` kullanici `admin_console` icine girebilir
- `free` kullanici `is_pro = true` icerigi okuyamaz
- `pro` kullanici `is_pro = true` icerigi okuyabilir
- Kanit artefact'leri `docs/verification/phase01_supabase_connection/` altinda bulunur

## 9. Ilerleme Durumu
- Durum: Devam ediyor
- Son guncelleme: 2026-03-08
- Kalan ana is: Faz 1'in anonim upgrade senaryosunu stage uzerinde UI smoke ile kapatip Faz 2'ye gecmek

## 10. Tamamlananlar / Notlar
- Supabase proje ref'i: `qretfjzaolpdguggcqfg`
- `supabase link --project-ref qretfjzaolpdguggcqfg` calistirildi
- `supabase db push` ile `014-024` migration'lari uzak projeye uygulandi
- `supabase migration list` sonucu yerel ve uzak setin `001-024` icin eslestigini dogruladi
- `scripts/seed_supabase_phase1_test_accounts.ps1` eklendi ve calistirildi
- `docs/verification/phase01_supabase_connection/verification.json` olusturuldu
- Dogrulanan test hesaplari:
  - `phase1.free@passagetr.dev` -> role `user`, plan `free`, pro erisimi `false`
  - `phase1.pro@passagetr.dev` -> role `user`, plan `pro`, pro erisimi `true`
  - `phase1.admin@passagetr.dev` -> role `admin`, plan `free`, admin gorunurlugu `true`
  - `phase1.developer@passagetr.dev` -> role `developer`, plan `free`, admin gorunurlugu `true`
- Tum test hesaplari icin ortak sifre seed script tarafinda `PassageTR#2026!` olarak kullanildi
- Kök neden notu:
  - `current_app_role()` fonksiyonu `user_roles` RLS politikasini dolayli olarak tekrar cagiriyordu
  - Sonuc: `stack depth limit exceeded`
  - Cozum: helper fonksiyonlar `security definer` olarak yeniden tanimlandi ve `024` migration'i eklendi
- `student_app` profiline seeded hesaplarla giris yapilabilen `Hesap erisimi` modal'i eklendi
- `admin_console` login ekrani seeded admin hesabiyla on-dolu hale getirildi
- Kanit klasoru: `docs/verification/phase01_supabase_connection/`
- Kanit dosyalari:
  - `android_student_app_home.png`
  - `student_web_home.png`
  - `student_web_profile.png`
  - `web_anonymous_auth.png`
  - `web_sign_out.png`
  - `admin_console_login.png`
- Dogrulanan komutlar:
  - `flutter analyze`
  - `flutter test apps/student_app`
  - `flutter test apps/admin_console`
  - `flutter build apk --debug --dart-define-from-file=env/app.web.json`
  - `flutter build web --release --dart-define-from-file=env/app.web.json`
  - `powershell -ExecutionPolicy Bypass -File .\\scripts\\smoke_web_auth.ps1 -AppName student_app -EnvironmentFile env\\app.web.json -SkipAnalyze -SkipTests`
