# Gemini Agent Manuel Web UI Test Talimati

Bu dokumanin amaci, Gemini agent'in web surumunu gercek tarayici uzerinde ayrintili olarak test etmesini ve sonuclari [manual_Uİ_TEST_sonuç.md](/c:/yazilim_projeler/ingilizce_app1/manual_Uİ_TEST_sonuç.md) dosyasina islemesini saglamaktir.

## Rol
- Tarayici kullanan bir manuel UI test agent'i gibi davran.
- Testleri gercek sayfa akislari uzerinden yap.
- Sadece teknik calisiyor mu kontrolu degil, kullanici deneyimi, okunabilirlik, hiz hissi, masaustu ergonomisi ve hata algisi da degerlendir.
- Web surumu yavas acilabilir; screenshot veya hata yorumu vermeden once yeterli bekleme yap.

## Test Edilecek Canli URL
- Uretim: `https://passagetr-fef48.web.app`

## Test Ortami
- Tarayici: Chrome veya Chromium tabanli browser
- Ilk test pencere boyutu: `1440 x 900`
- Ek test boyutlari:
  - `1280 x 720`
  - `1024 x 768`
  - `390 x 844` (responsive fallback kontrolu)

## Kritik Bekleme Kurallari
- Sayfa ilk acilista yavas olabilir. Her ana route gecisinden sonra en az `8 saniye` bekle.
- Eger skeleton, bos beyaz alan, yarim cizilmis kart veya gec kalan ikonlar goruluyorsa ek olarak `5 saniye` daha bekle.
- Screenshot almadan once su kosullarin saglandigindan emin ol:
  - yazilar son haline gelmis olmali
  - ikonlar ve fontlar yuklenmis olmali
  - kart yukseklikleri stabil olmali
  - loading state gercekten bitmis olmali
- Hizli ekran goruntusu alip yanlis negatif uretme. Ozellikle gramer ve kelime ekranlarinda bunu dikkate al.

## Sonuc Yazim Zorunlulugu
- Tum sonuclari [manual_Uİ_TEST_sonuç.md](/c:/yazilim_projeler/ingilizce_app1/manual_Uİ_TEST_sonuç.md) dosyasina yaz.
- Bu dosyada:
  - test tarihi
  - kullanilan browser
  - test edilen ekran boyutlari
  - ekran bazli bulgular
  - bulunan bug'lar
  - kullanilabilirlik sorunlari
  - hiz/perf gozlemleri
  - kullanici dostulugu onerileri
  - genel sonuc
  yer almali.

## Screenshot Kurallari
- Her ana ekran icin en az bir ekran goruntusu al.
- Sorun bulunan her ekran icin ek ekran goruntusu al.
- Screenshot dosya adlari su formatta olmali:
  - `ui_home_desktop.png`
  - `ui_words_desktop.png`
  - `ui_pack_detail_desktop.png`
  - `ui_flashcard_desktop.png`
  - `ui_reading_home_desktop.png`
  - `ui_reading_detail_desktop.png`
  - `ui_grammar_home_desktop.png`
  - `ui_grammar_module_list_desktop.png`
  - `ui_grammar_reader_desktop.png`
  - `ui_profile_desktop.png`
- Sorun goruntu adlari:
  - `issue_<ekran>_<kisa_aciklama>.png`

## Test Ciktisi Standarti
- Her ekran icin su formatta not ver:
  - `Durum: Gecti / Kismi / Basarisiz`
  - `Teknik Bulgular`
  - `UX Bulgulari`
  - `Performans Bulgulari`
  - `Oneriler`
- Her bug icin severity kullan:
  - `Kritik`
  - `Yuksek`
  - `Orta`
  - `Dusuk`

## Genel Kontrol Listesi
- Desktop layout `1024px` ve uzerinde aktif mi?
- Sol navigasyon rail gozukuyor mu?
- Bottom navigation desktop'ta gorunuyor mu? Gorunuyorsa bug say.
- Kartlar masaustunde asiri yuksek veya bos mu?
- Butonlar gereksiz tam genislikte mi?
- Hover ve pointer hissi dogal mi?
- Tooltip/Material sistem metinleri Turkce mi?
- UI genel olarak web/masaustu urunu gibi hissettiriyor mu, yoksa buyutulmus mobil gorunumu mu?

## Ekran Bazli Testler

### 1. Ana Sayfa
- Ana Sayfa'yi ac.
- `1440 x 900` boyutunda:
  - sol rail gorunuyor mu
  - hero ve metrikler ayrisiyor mu
  - kartlar asiri dikey bosluk birakiyor mu
  - CTA kullaniciya hizli anlasilir mi
- Sonra `1024 x 768` boyutunda tekrar kontrol et.

Beklenen:
- Desktop shell aktif olmali.
- Icerik ortalanmali.
- Hero ve metrik bloklari masaustu icin dengeli gorunmeli.

### 2. Kelime Ana Sayfasi
- `Kelime` sekmesini ac.
- Sol panelde su ogeleri kontrol et:
  - arama alani
  - `Ara`
  - `Seviye Merkezi`
  - sonuc/filtre ozeti
- Sag panelde su ogeleri kontrol et:
  - paket listesi
  - kart yogunlugu
  - bos alan kullanimi

Yap:
- `abandon` ara
- filtreleri tek tek dene: `Tumu`, `Kelime Karti`, `Sozluk`
- `Temizle` ile listeye geri don

Beklenen:
- Sol panel sabit ve rahat kullanilir olmali.
- Sag alan tek kolon mobil gibi akmamalı.
- Paket kartlari gereksiz uzun olmamali.

### 3. Paket Detay
- `YDS Set 001` veya benzeri bir paketi ac.
- Desktop'ta paket detay ekranini incele.
- Aksiyon alanlarini kontrol et:
  - `Kelime Calis`
  - `Test`
  - `Kelime Listesi`

Beklenen:
- Uc buyuk dikey tam-genislik buton hissi olmamali.
- Sol tarafta paket ozeti, sag tarafta aksiyonlar net ayrismali.
- Kisa metrikler okunakli olmali.

### 4. Flashcard Ekrani
- Paket detaydan `Kelime Calis` akisini ac.
- Asagidakileri kontrol et:
  - calisma alani cok genis ve bos mu
  - kart merkezi hizalanmis mi
  - alt aksiyon bar'i desktop'ta asiri uzun mu
  - sag panel istatistikleri faydali mi
- Klavye kontrolu:
  - `Left`
  - `Up`
  - `Right`

Beklenen:
- `Left = Bilmem`
- `Up = Kararsiz`
- `Right = Bilirim`
- Aksiyon bar icerik kolonu ile hizali olmali.

### 5. Okuma Ana Sayfasi
- `Okuma` sekmesini ac.
- Asagidakileri kontrol et:
  - hero
  - okumaya devam et
  - segment kontrolu
  - passage kart grid yogunlugu

Beklenen:
- Desktop'ta kartlar tek kolon buyutulmus mobil gibi gorunmemeli.
- 2 kolonlu feed taranabilir olmali.

### 6. Okuma Detay
- Bir passage ac.
- Su alanlari test et:
  - sol meta panel
  - orta metin alani
  - sag detay paneli
- Eylemler:
  - kelimeye tikla => sag panelde sozluk
  - cumleye uzun bas ya da tanimli desktop etkileşimi ile ceviri
  - TTS butonuna bas

Beklenen:
- Sag panel bosken yardimci durum acik olmali.
- TTS web'de Ingilizce sesle calismali.
- Orta alan cok genis olmamali.

### 7. Gramer Ana Sayfasi
- `Gramer` sekmesini ac.
- Kontrol et:
  - `Son kaldigin yer` karti
  - moduller grid'i
  - kart yukseklikleri
  - ilerleme bilgileri

Beklenen:
- Kartlar daha yogun olmali.
- Bos beyaz alan cok olmamali.
- Resume karti belirgin olmali.

### 8. Gramer Modul Sayfa Listesi
- Bir gramer modulune gir.
- Kontrol et:
  - solda modul ozeti
  - sagda sayfa listesi
  - satir yogunlugu
  - resume/ileri isaretleri

Beklenen:
- Sayfa listesi mobile listeden daha yogun ve daha hizli taranabilir olmali.

### 9. Gramer Reader
- Bir gramer ders sayfasini ac.
- Asagidakileri kontrol et:
  - altta sabit navigasyon
  - `Geri`
  - `Ileri`
  - son sayfada `Dersi Bitir`
- Klavye testi:
  - `Left` geri gidiyor mu
  - `Right` ileri gidiyor mu

Beklenen:
- Tek `Devam Et` butonu artik olmamali.
- Footer bar masaustu icin mantikli ve sabit olmali.

### 10. Profil
- `Profil` sekmesini ac.
- Desktop'ta bloklarin iki kolonlu, taranabilir ve duzenli olup olmadigini kontrol et.

## Performans Analizi Kurallari
- Her ekran icin ilk kullanima hazir olma hissini yorumla.
- Teknik metrik bilmesen bile su siniflandirmayi kullan:
  - `Hizli`
  - `Kabul Edilebilir`
  - `Yavas`
  - `Sorunlu`
- Asagidaki durumlari ayri not et:
  - route gecisinde gecikme
  - font/ikon gec yuklenmesi
  - layout ziplamasi
  - TTS aksiyonuna gec yanit
  - scroll takilmasi

## Kullanici Dostulugu Degerlendirmesi
Her ekran sonunda su sorulara cevap ver:
- Ilk kez kullanan biri ne yapacagini hizlica anlar mi?
- Ekranin asil amaci yeterince net mi?
- Gereksiz bosluk veya gereksiz CTA var mi?
- Desktop kullanan biri kendini mobil buyutmesi kullaniyor gibi hisseder mi?

## Oneri Sunma Zorunlulugu
- Sadece hata yazma; her ekran icin en az bir iyilestirme onerisi sun.
- Onerileri asagidaki kategorilerle ver:
  - `Yerlesim`
  - `Gorsel Yogunluk`
  - `Okunabilirlik`
  - `Etkilesim`
  - `Performans`

## Son Cikti Kurali
- Tum test bittikten sonra [manual_Uİ_TEST_sonuç.md](/c:/yazilim_projeler/ingilizce_app1/manual_Uİ_TEST_sonuç.md) dosyasini doldur.
- Son satirda su uc yargiyi ver:
  - `Genel Teknik Durum`
  - `Genel UX Durumu`
  - `En Oncelikli 5 Iyilestirme`
