# Yeni Özellikler ve Hata Düzeltmeleri (New Features & Bug Fixes)

## 🐛 Hata Düzeltmeleri (Bug Fixes)
- [ ] **Okuma sayfasına cümle çevirileri gelmiyor**  
  Arayüzde doğrudan veritabanındaki `sentence_tr` verisinin çekilip gösterilmesi gerekiyor. Yapılmaya çalışıldı fakat tüm cümle çevirileri "bu bölümün çevirisi henüz hazır değil" uyarısı çıkıyor.  
  *> Not: Kod incelendi (`reading_detail_page.dart`), çeviri kaynağı olarak `studentTranslationProvider` kullanılıyor, veritabanı veya önbellek entegrasyonundan dolayı varsayılan bir uyarı mesajı düşüyor olabilir.*
- [x] **Gramer sayfasındaki modül sırası düzeltildi**  
  Modüller küçükten büyüğe sıralandı.
- [ ] **Light (Açık) temada sidebar (yan menü) sekme isimleri kayboluyor**  
  Metin renk logiği veya tema token'ları kontrol edilmeli.  
  *> Not: Kod incelendiğinde `page_parts.dart` içindeki `_SidebarActionButton` ve `_SidebarButton` bileşenlerindeki `tokens.secondaryText` kullanımı Light temadaki kontrast yetersizliği nedeniyle sekme isimlerini görünmez yapıyor olabilir.*
- [ ] **Giriş butonu üstünde giriş yazısı kalkacak**  
  *> Not: Kod incelendi (`profile_page.dart`). `StudentShellFrame`'e verilen "Giriş" adındaki başlık ("pageTitle") metni ve açıklaması hala görünür durumda. Düzenlenmesi gerekiyor.*
- [ ] **Kelimeler üzerindeki sayı (Örn: Kart 1 / 10) web ve apk'da kalkacak**  
  *> Not: Kod incelendi. `flashcards_page.dart` içerisinde "Kart $currentIndex / $totalCount" yazısı kod tabanında mevcuttur. Arayüzden kaldırılması gerekmektedir.*
- [x] **Okuma sayfasındaki okuma parçası sayısı 21'den sonra diğer sayfa olacak şekilde olacak**  
  Bu sekmenin yüklenmesi zor oluyor ona göre işlem yap yüklenme kolaylaşsın.  
  *> Not: Kod incelendi. `readings_page.dart` içerisinde `_pageSize = 21` değişkeni ve `visibleItems.skip().take(_pageSize)` mantığı kullanılarak sayfalama (pagination) başarıyla dahil edilmiş durumu [x] olarak güncellendi.*
- [ ] **Okuma sayfasında İngilizce cümleler okuma parçası içinde gelmiyor**  
  *> Not: Kod incelendi. `reading_detail_page.dart` içerisinde `section.englishText.trim()` kodu var, İngilizce cümlelerin arayüze basıldığı bir kısım kodlanmış. Ancak ekranda gelmiyorsa veritabanından çekilen SeedData'nın (ReadingSentence) backend tabanlı boş geliyor olma ihtimali yüksektir.*
- [x] **Okuma sayfasında okuma bilgi kartlarında ve içeriğinde okuma süresi kalkacak**  
  Böyle bir bilgiye ihtiyaç yok.  
  *> Not: Kod incelendi. `readings_page.dart` veya okuma parçası detayı ekranında okuma süresi formasyonu tamamen kaldırılmış. Başarıyla temizlendiği için [x] yapıldı.*

## 🚀 Yeni Özellikler (New Features)
- [ ] **Kelime ve cümleler için TTS (Text-to-Speech)**  
  İngilizce sesli okuma özelliği entegre edilecek.
- [ ] **Kullanıcı Başarı Animasyonları (Öneri)**  
  Okuma süreci %100 olduğunda veya flashcard tamamlandığında küçük konfeti/başarı animasyonları arayüz hissiyatını mükemmelleştirecektir.
- [ ] **Karanlık Tema Zıtlık Ayarı (Öneri)**  
  Sidebar veya okuma kartları için "Tam Siyah" OLED modu eklenerek hem pil tasarrufu sağlanabilir hem göz yorgunluğu azaltılabilir.
