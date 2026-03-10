# PASSAGETR v2 Ürün İyileştirme ve QA / UX Önerileri

Bu doküman, üretim ortamı canlı smoke test raporu, Figma UI/UX sözlüğü ve gap analiz belgelerinin sentezlenmesi ile oluşturulmuş, somut ve karar odaklı ürün geliştirme tavsiyelerini içerir.

## 1. Yönetici Özeti
Canlı UI parity ve smoke testleri göstermiştir ki; `admin_console` mevcut web yapısıyla büyük oranda stabil ve Figma ile uyumlu görünürken, `student_app` web dağıtımında route (yönlendirme) mekanizmalarında kritik çökmeler ve UI bazında büyük farklılıklar barındırmaktadır. Kırmızı (Critical) seviyedeki "beyaz root ekranı" ve "sabit ana sayfa render" sorunları doğrudan projenin kullanılabilirliğini bloke etmektedir. Ayrıca profil ekranının yalnızca bir debug paneli olması, ürünün canlıya çıkışı önünde majör bir UX engelidir. Teknik tarafta Supabase backend ve izole edilmiş admin/student mimarisini koruyarak, önceliğimizi web routing sorunlarına ve platform parity eksiklerine (asset, tipografi, font) vermeliyiz. Android test altyapısının (`adb`, emulator) sisteme entegrasyonu da QA süreçlerinin devamlılığı için zaruridir.

---

## 2. En Kritik 10 İyileştirme Önerisi

**1. Root URL Beyaz Ekran Hatası (White Screen on `/`)**
- **Problem:** Kullanıcı doğrudan `https://passagetr-fef48.web.app/` adresine girdiğinde sayfa hiçbir eleman veya hata mesajı göstermeksizin tamamen beyaz kalmaktadır.
- **Kullanıcı Etkisi:** Uygulamanın çöktüğünü sanıp doğrudan sistemi terk etme.
- **Öncelik:** `P0`
- **Önerilen Çözüm:** `student_app` içerisindeki Router yapılandırmasında (veya AuthGuard middleware'inde) un-authenticated ve authenticated durumlar için spesifik yönlendirme (`/words` veya ana dashboard) root path fail-safe mekanizması ile garantiye alınmalıdır.
- **Etkilenen Ekran:** Root (`/`)

**2. Route Yenileme ve Component Sabitleme Hatası**
- **Problem:** `/words`, `/grammar` gibi alt adreslere doğrudan girildiğinde dahi route değişmesine rağmen UI "Ana Sayfa (Hoşgeldin Ahmet)" komponentinde sabit kalmaktadır.
- **Kullanıcı Etkisi:** Kullanıcı başka bölümlere navigasyon sağlayamaz, uygulama bloklanmış hissiyatı verir.
- **Öncelik:** `P0`
- **Önerilen Çözüm:** Router outlet, `MaterialApp.router` (Flutter) veya ilgili frontend tabanlı route state provider mekanizması incelenerek nested path'lerin parent component ile bundle olması engellenmeli, her path'in kendi widget'ını veya sayfa render ağacını tetiklediği doğrulanmalıdır.
- **Etkilenen Ekran:** Tüm Student Web Route'ları

**3. Profil Ekranının Yeniden Yazılması**
- **Problem:** Mevcut `/profile` ekranı Figma mockuplarında yer alan gerçek son kullanıcı görünümüyle %85 uyumsuzdur ve tamamen QA/geliştirici test paneli olarak görev yapmaktadır.
- **Kullanıcı Etkisi:** Gerçek kullanıcı kendi bilgilerini göremez, ayar yapamaz veya plan yükseltme seçenekleriyle karşılaşmaz.
- **Öncelik:** `P0`
- **Önerilen Çözüm:** Debug panelinin tamamen gizli bir dev-menu'ye (`/dev-admin` vb.) taşınması ve `docs/ui_tasarim/` altındaki profile spesifikasyonlarına (Avatar, PRO banner, Tema, Hesap Yönetimi) uygun yepyeni bir `StudentProfilePage` oluşturulması.
- **Etkilenen Ekran:** `/profile`

**4. Tipografi ve Figma Font Ailesinin (Outfit/Inter) Entegrasyonu**
- **Problem:** Sistem şu anda varsayılan (Roboto/M3) fontları kullanmakta olup, bu durum kurumsal markalama hedefi olan "Outfit" veya "Inter" font tasarımını bozmaktadır. Ayrıca Türkçe karakter sorunları (ğ, ü, ş, ı, ö, ç) yaşanmaktadır.
- **Kullanıcı Etkisi:** Ürünün premium hissiyati düşer, dil bilgisi hatalı metinler kalitesizlik algısı yaratır.
- **Öncelik:** `P1`
- **Önerilen Çözüm:** Proje asetleri arasına kullanılacak font ailesinin `.ttf / .otf` formatları dahil edilerek global `TextTheme` üzerinden varsayılan olarak tanımlanması ve uygulamadaki tüm hardcoded metinlerin dil düzeltmelerinin (Türkçe encoding uyumlu) yapılması.
- **Etkilenen Ekran:** Tüm Uygulama

**5. Gerçek Görsel Assetlerin (Artwork) Sisteme Eklenmesi**
- **Problem:** Okuma ve Kelime paketleri ekranlarında, tasarımdaki gerçekçi doğa, kahve vb. fotoğraflar yerine gradient placeholder veya ikonlar kullanılmaktadır.
- **Kullanıcı Etkisi:** İçerik görsel cazibesini kaybeder, tasarımdaki zenginlik hissedilmez.
- **Öncelik:** `P1`
- **Önerilen Çözüm:** Öğretim içeriklerinin seed datalarına (DB kayıtlarına veya lokal varlıklara) Figma tasarımlarındaki base fotografların düşük boyutlu / optimize (.webp vb.) halleri bağlanmalı ve placeholder mantığı yalnızca network hatası durumları için tutulmalıdır.
- **Etkilenen Ekran:** `/readings`, `/readings/:id`

**6. Android Test Altyapısının (Emulator) Otomatize Edilmesi**
- **Problem:** CI ortamında veya Agent çalışma alanında `adb` bulunmadığından Flutter uygulamasının kritik Native performans ve UX testleri gerçekleştirilemiyor.
- **Kullanıcı Etkisi:** Mobil sürümdeki dokunma tepkisi hataları ve UI taşmaları canlıda doğrudan son kullanıcıya yansır.
- **Öncelik:** `P1`
- **Önerilen Çözüm:** Test pipeline içerisine Headless Android Emulator veya `adb` ortam yönergelerini içeren stabil bir environment script eklenmesi ve e2e akışlara bağlanması.

**7. Web Platformu Responsive UX Ayarlaması**
- **Problem:** Responsive olmayan UI kodlaması yüzünden, Desktop browser üzerindeki `student_app` ekranları mobili doğrudan ekrana basan bir canvas ya da ekran boyunca esneyen kalitesiz panel görünümleri sunmaktadır.
- **Kullanıcı Etkisi:** Masaüstü web platformundan ders çalışan öğrenci verimsiz ve bozuk layout ile karşılaşır.
- **Öncelik:** `P1`
- **Önerilen Çözüm:** Mevcut layout yapısında, desktop layout kuralı (≥960px) devredeyse içerik `maxWidth: 1120px` wrapper'ına sabitlenip (center align) web'e özel padding margin yapısı (Gap analysis tablosundaki LayoutBuilder'a göre) kesin olarak ayrıştırılmalıdır.
- **Etkilenen Ekran:** Tüm Student Web

**8. Eksik Renk Tokenları ve Dark Mode Theme Kurulumu**
- **Problem:** Pro_Pill ve PackAccent (`#FF6A3D`, `#3B82F6`) gibi renkler UI tarafında "hardcoded" tutulmakta, Dark Mode ise sadece isminde olup tasarımsal olarak tokenized bir altyapıya sahip değildir.
- **Kullanıcı Etkisi:** Koyu temaya geçişlerde ekran okunamayacak seviyede kontrastsız ve bozuk görünür. Marka bütünlüğü de zamanla kod içinde dağılır.
- **Öncelik:** `P2`
- **Önerilen Çözüm:** Figma Style Dictionary içerisindeki token haritası temel alınarak `AppThemeTokens` genişletilmeli, ColorScheme override'ı light ve dark olarak ayrıştırılmalıdır.
- **Etkilenen Ekran:** Temel Arayüz, `AppTheme`

**9. Admin Console Oturum Güvenliği Sağlama**
- **Problem:** `admin_console` üzerinde aktif ve süre kontrollü oturum kapatma davranışları belirsiz.
- **Kullanıcı Etkisi:** Eski bir oturum güvenlik açığı oluşturur.
- **Öncelik:** `P2`
- **Önerilen Çözüm:** Supabase Session Expire lifecycle'ını dinleyecek bir Auth provider wrapper'ı ekleyip, token düştüğünde anında `/login`'e force redirect tetiği güvenceye alınmalı.
- **Etkilenen Ekran:** `admin_app` Geneli

**10. Offline Caching / State Senkronizasyonu**
- **Problem:** İnternet erişimi koptuğunda UI fallback veya lokal state gösterimi çalışmıyor.
- **Kullanıcı Etkisi:** Kelime veya gramer ekranında anlık bağlantı kopmaları içerik okumasını kırar.
- **Öncelik:** `P2`
- **Önerilen Çözüm:** Supabase sorgularına bir lokal caching katmanı dahil edilmesi veya Repository layer'da statik veri önbellekleme yaklaşımının aktifleştirilmesi.

---

## 3. UI/UX Önerileri
- **Gestures ve Mikro-Animasyonlar:** Kelime kartlarında "Swiping" (Tinder benzeri sağa-sola atma) animasyonları öğrenmeyi hızlandırır. Mobil arayüzde kart tasarımları bu yapıyla entegre edilmelidir.
- **Hover Değişimleri:** Web kullanıcıları için `student_app` üzerinde Mouse üzerine geldiğinde (hover state) gölge (drop shadow blur) büyütmeleri eklenmelidir.
- **Tooltip ve Metrik Panelleri:** "Haftalık İlerleme" veya menülerde, progress barlarda küçük bilgilendirici araç ipuçları (Tooltips) kullanımı ürün hissini profesyonelleştirir.

## 4. Student Web / Mobile Önerileri
- **Mobil Native UX Dağılımı:** Web responsive yapıları tasarlanırken, "Navigation Rail" (sol menü) 960px üzerinde kullanılmalı, alt sınırda anında Native `BottomNavigationBar` yapısına çevrilmelidir (şuan kısmen yapılmışsa da router sorunu yüzünden davranışı felç konumda).
- **Pro Banner Görünürlüğü:** Satın alıma ikna edecek olan Premium yükseltme bayrak banner'ları profil haricinde Kelimeler ve Ana Sayfa altında belli limitlerden sonra proaktif hale getirilmelidir.
- **Artwork Placeholder Değişimi:** Gerçek görselleri koyana kadar, en azından marka desenli SVG vector çizimler konulmalıdır (Basit renkli gradientler mobil uygulamayı basitleştiriyor).

## 5. Admin Web Önerileri
- **Grid View ve Data Tables:** Yönetim panelinde veri sayısı arttıkça oluşacak daralmayı önlemek için, mobil admin paneline odaklanmaktan ziyade Table View genişlikleri minimum 1200px viewport'a optimize edilmeli (Adminler genelde Desktop'tan kullanır).
- **Bulk (Toplu) Eylemler:** "Content Operations" ekranlarına mutlaka toplu silme, toplu onaylama checkbox yetenekleri konulmalıdır.

## 6. Production Smoke ve Regression Test Kapsamı Önerileri
- **Kapsam:** Her master merge'den önce çalışacak bir `Playwright` veya `Puppeteer` pipeline build sürecine kurulmalı. Öncelik "Login -> Dashboard render -> İlk 3 route navigate -> Not Found (404) dönmeme garantisi" şeklinde olmalıdır.
- **Gerçek Auth Testleri:** Dummy kullanıcı üzerinden test etmek yerine, Supabase ortamında tamamen Test'e ayrılmış statik kullanıcı ve anonim kullanıcı akışları End-to-End otomasyona dahil edilmelidir.

## 7. Performans / Cache / Responsive Önerileri
- **Web App Boyutu Limitleri:** Flutter Web veya PWA ile render süresi yüksek olabilir. `flutter build web --wasm` ile veya canvaskit optimizasyonlarıyla initial sayfa yükleme gecikmesi minimize edilmelidir. O zamana değin beyaz ekranın yerini alacak bir Native HTML Progress Spinner root `index.html` altına konmalıdır.
- **Asset Caching:** Görseller external network yerine PWA manifest ile önbelleklenmeli.

## 8. Önceliklendirilmiş Backlog
1. **[P0-BUG]** `student_app` Root UI (White screen error on /) tamiri.
2. **[P0-BUG]** `student_app` Router state mismatch tamiri (Her ekranda aynı Dashboard gelmesi).
3. **[P0-FEAT]** Student Profil Ekranının (Debug Panel → Gerçek Kullanıcı Paneli) yeniden yazılması.
4. **[P1-FEAT]** Android Emulator/adb entegrasyonu ile pipeline lokal test desteğinin açılması.
5. **[P1-UX]** Font (Outfit vb.) ve Türkçe karakter sorunlarının global `theme.dart` çapında çözülmesi.
6. **[P1-UX]** Okuma listelerinde gerçek Media Asset (Artwork/Photos) desteği sağlanması.
7. **[P1-UX]** Web Responsive Desktop UI grid sınırlaması ve padding düzeltmeleri.
8. **[P2-UX]** Dark Mode Tema Renk Sözlüğünün Kodlanması ve Token eksikliklerinin kapatılması.
9. **[P2-FEAT]** Admin Auth Guard Expire yönetiminin garantilenmesi.
10. **[P2-PERF]** PWA IndexedDB/Cache mekaniği entegrasyonu.
