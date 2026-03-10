# PASSAGETR v2 Live UI and Production Test Guide

Bu kilavuz, bu IDE icindeki baska bir agentin browser ve emulator kullanarak canli sistemi ayrintili test etmesi icin hazirlanmistir. Bu dokumanin amaci kod degisikligi yaptirmak degil, canli ortam davranisini ve UI parity durumunu sistematik bicimde dogrulatmaktir.

## 1. Amac

- `student_app` production web ve Android APK davranisini test etmek
- `admin_console` production web davranisini test etmek
- UI parity, route davranisi, auth, role/plan gorunurlugu ve temel regresyonlari yakalamak
- Sonuclari bana aktarilacak iki ayri markdown dosyasinda toplamak

## 2. Kapsam

Kapsam dahilinde:

- Canli student web: `https://passagetr-fef48.web.app`
- Canli admin web: `https://passagetr-admin.web.app`
- Android emulator uzerinde `student_app`
- Browser uzerinde route, auth, role ve temel UI smoke
- `docs/ui_tasarim/` referansina gore gorunur UI farklari

Kapsam disi:

- Kod degisikligi
- Firebase deploy
- Supabase migration
- Yeni test hesabi olusturma
- Veritabani seed degisikligi

## 3. Test Ciktilari

Diger agent, test sonunda su iki dosyayi ilgili klasorlerine yazmalidir:

1. `docs/verification/other_agent_live_test/results.md`
2. `docs/reports/other_agent_product_improvement_suggestions.md`

Ek kanit ekran goruntuleri su klasore yazilmalidir:

- `docs/verification/other_agent_live_test/`

## 4. Test Ortami Sabitleri

### Production URL'ler

- Student web: `https://passagetr-fef48.web.app`
- Student profil: `https://passagetr-fef48.web.app/profile`
- Admin web: `https://passagetr-admin.web.app`
- Admin login: `https://passagetr-admin.web.app/login`

### Test Hesaplari

Ortak sifre:

- `PassageTR#2026!`

Hesaplar:

- Free: `phase1.free@passagetr.dev`
- PRO: `phase1.pro@passagetr.dev`
- Admin: `phase1.admin@passagetr.dev`
- Developer: `phase1.developer@passagetr.dev`

## 5. Emulator ve Browser Beklentisi

Diger agent su iki ortami birlikte kullanmalidir:

- Browser: canli production URL'lerde gercek smoke
- Android emulator: son uretilen APK veya `flutter run` ile `student_app`

Browser testlerinde:

- Console error
- Failed network request
- 404/403/500
- route refresh davranisi
- login/logout akisi
- admin yonlendirmesi

kontrol edilmelidir.

Emulator testlerinde:

- Ana akislar
- Navigation
- Profil / auth
- Kelime paketi tiklama davranisi
- Okuma parcasi detay ve ceviri davranisi
- Admin launcher

kontrol edilmelidir.

## 6. Zorunlu Test Matrisi

### Student Web

Asagidaki route'lar tek tek acilmalidir:

- `/`
- `/words`
- `/readings`
- `/readings/:id` en az bir gecerli icerik ile
- `/grammar`
- `/profile`
- `/admin`

Asagidaki davranislar test edilmelidir:

- Sayfa acilisinda UI bozulmasi var mi
- Hard refresh sonrasi route calisiyor mu
- Profil ekraninda Free / PRO / Admin hesaplari ile login calisiyor mu
- PRO yuzeyleri dogru gorunuyor mu
- Admin hesabinda `Admin` butonu gercek admin web'i aciyor mu
- Kelime paketine tiklayinca detay veya beklenen akis aciliyor mu
- Okuma detayinda ceviri ac/kapa davranisi calisiyor mu
- Grammar ekraninda kart ve detay akisi calisiyor mu

### Admin Web

Asagidaki route veya ekranlar kontrol edilmelidir:

- `/login`
- `/`
- `/users`
- `/content`
- `/settings`

Asagidaki davranislar test edilmelidir:

- Admin login calisiyor mu
- Non-admin hesap ile erisim reddediliyor mu
- Dashboard aciliyor mu
- Users / Content / Settings ekranlari bos veya kirik mi
- Tablo, filtre, toolbar, buton ve temel aksiyonlarda UI bozulmasi var mi

### Emulator Uzerinde Student App

Asagidaki alanlar test edilmelidir:

- Ana sayfa
- Kelimeler
- Okuma
- Gramer
- Profil
- Admin launcher

Asagidaki davranislar test edilmelidir:

- Navigasyon bar / sidebar tepki veriyor mu
- Kelime paketi tiklamasi tepki veriyor mu
- Okuma detay aciliyor mu
- Ceviri akisi calisiyor mu
- Profil login/logout calisiyor mu
- Admin butonu web admin adresine yonlendiriyor mu

## 7. UI Parity Kontrolu

Diger agent su klasoru referans almak zorundadir:

- `docs/ui_tasarim/`

Kontrol noktasi:

- Layout hiyerarsisi
- Bosluklar
- Kart stilleri
- Baslik hiyerarsisi
- Renk / badge / CTA kullanimi
- Responsive davranis
- Admin web ekranlarinin `docs/ui_tasarim/web` taslaklari ile uyumu

UI parity yorumu yaparken su ayrimi kullan:

- `Tam uyumlu`
- `Kucuk fark`
- `Belirgin fark`
- `Kirici uyumsuzluk`

## 8. Hata Raporlama Kurali

Her bug icin su format kullanilmalidir:

- ID
- Platform: `student_web`, `admin_web`, `android_emulator`
- URL veya ekran
- Test hesabi
- Yeniden uretme adimlari
- Beklenen sonuc
- Gercek sonuc
- Siddet: `kritik`, `yuksek`, `orta`, `dusuk`
- Kanit ekran goruntusu yolu
- Varsa console/network hatasi

## 9. Kanit Kurali

Ekran goruntuleri zorunludur:

- Giris ekrani
- Student ana sayfa
- Student kelimeler
- Student okuma detay
- Student gramer
- Student profil
- Student admin launcher
- Admin login
- Admin dashboard
- En az 1 bug icin yakin ekran goruntusu

Dosya adlari acik olmali:

- `student_web_home.png`
- `student_web_profile_admin.png`
- `student_web_reading_translation.png`
- `admin_web_login.png`
- `admin_web_dashboard.png`
- `android_emulator_words.png`

## 10. Sonuc Dosyalarinin Icerigi

### `docs/verification/other_agent_live_test/results.md`

Icerik sirasi:

1. Test kapsami
2. Kullanilan ortamlar
3. Test edilen URL ve hesaplar
4. Gecen senaryolar
5. Bulunan bug listesi
6. UI parity bulgulari
7. Riskler
8. Genel sonuc: `production uygun`, `sinirli uygun`, `uygun degil`

### `docs/reports/other_agent_product_improvement_suggestions.md`

Icerik sirasi:

1. En kritik 10 iyilestirme onerisi
2. UI/UX onerileri
3. Test kapsami eksikleri
4. Performans / cache / responsive onerileri
5. Admin panel gelistirme onerileri
6. Student uygulama gelistirme onerileri
7. Onceliklendirilmis backlog

## 11. Kurallar

- Kod degistirme.
- Git commit atma.
- Deploy etme.
- Env degistirme.
- Seed hesaplari bozma.
- Uydurma test sonucu yazma.
- Gormedigi ekrani test edilmis gibi raporlama.

## 12. Beni Ne Sekilde Bilgilendirecek

Diger agent bana dogrudan mesaj atmayacak. Bunun yerine:

- `docs/verification/other_agent_live_test/results.md`
- `docs/reports/other_agent_product_improvement_suggestions.md`

dosyalarini ilgili klasorlerine yazacak. Ben bu iki dosyayi okuyup gerekli duzeltmeleri yapacagim.
