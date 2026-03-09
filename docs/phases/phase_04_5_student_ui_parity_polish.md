# Faz 4.5 - Student UI Parity Polish

## 1. Faz Amacı
`apps/student_app` içindeki öğrenci yüzeylerini Figma parity geri bildirimine göre polish etmek ve kullanıcıya görünen tasarım açıklarını kapatmak.

## 2. Kapsam
- `shared_ui` tema ve token polish
- `student_app` typography ve Türkçe metin düzeltmeleri
- profil ekranı redesign
- okuma artwork asset stratejisi
- tema seçici ve UI-only `ThemeMode` state

## 3. Kapsam Dışı
- Admin console parity
- Translation cache
- Reader data persistence
- Grammar/reading domain mantığı değişiklikleri
- Yeni repository veya route modeli

## 4. Yapılacak İşler
- [x] Faz çalışma dosyasını oluştur
- [x] Faz 3 ve Faz 4 dokümanlarına ara faz referans notunu işle
- [x] `AppThemeTokens` içine `badgeOrange` ve `accentBlue` ekle
- [x] `shared_ui` tema yapısını `Outfit` + tam dark theme ile simetrik hale getir
- [x] `studentThemeModeProvider` ekle ve `student_app` içine bağla
- [x] Kullanıcıya görünen tüm string'leri Türkçe karakterlerle normalize et
- [x] Hardcoded renkleri token'a taşı
- [x] `StudentPackCard` ve nav label stil polish'ini tamamla
- [x] Profil ekranını son kullanıcı yüzeyine çevir, dev paneli koşullu koru
- [x] Reading artwork asset yapısını aç ve `Image.asset` + fallback bağla
- [x] Ara faz çıkış testlerini çalıştır ve sonucu kaydet

## 5. Teknik Kararlar
- Font kararı sabit: `Outfit`
- Yeni renk tokenları sabit: `badgeOrange`, `accentBlue`
- Theme state yalnız UI state olur; auth veya repository katmanına dokunmaz
- Reading artwork stratejisi lokal asset ile başlar: `apps/student_app/assets/images/readings/`
- Asset adları sabit: `silent_ocean.webp`, `brief_history.webp`, `coffee_shops.webp`
- Profil sayfasındaki mevcut auth shell silinmez; `_DevAccessPanel` olarak yalnız `admin` ve `developer` rollerinde görünür
- `FilledButton` ve `OutlinedButton` minimum size tanımı `Size(0, h)` ile tutulur; satır içi kullanımlarda sonsuz genişlik verilmez

## 6. Bağımlılıklar
- Faz 3 shell parity
- Faz 4 reading/grammar parity
- `shared_ui` ve `student_app` mevcut router kabuğu

## 7. Riskler
- Font değişikliği layout shift yaratabilir
- Asset decode hatası artwork alanlarında fallback gerektirir
- Profil redesign sırasında dev auth yardımcıları kaybedilirse Faz 1 test yüzeyi zarar görür

## 8. Test ve Kabul Kriterleri
- `flutter analyze` başarılı olmalı
- `flutter test apps/student_app` başarılı olmalı
- `flutter test apps/admin_console` başarılı olmalı
- `flutter build apk --debug` başarılı olmalı
- `flutter build web --release` başarılı olmalı
- `/`, `/words`, `/readings`, `/readings/:id`, `/grammar`, `/profile` ekranları Figma geri bildirimindeki parity açıklarını kapatmalı

## 9. İlerleme Durumu
- Durum: Tamamlandı
- Son güncelleme: 2026-03-08

## 10. Tamamlananlar / Notlar
- Ara faz dosyası oluşturuldu
- Bu faz yalnız `student_app` ve `shared_ui` kapsamındadır
- `phase_03` ve `phase_04` dokümanları ara faz notuyla hizalandı
- `Outfit` fontu ve yeni renk tokenları tanımlandı
- `studentThemeModeProvider` uygulamaya bağlandı
- Profil ekranı avatar başlığı, PRO banner, uygulama ayarları ve hesap yönetimi kartlarıyla yenilendi
- Dev auth/RBAC aracı `_DevAccessPanel` olarak yalnız admin/developer oturumlarında korunur
- Reading artwork desteği `assets/images/readings/` altına taşındı ve `Image.asset` + gradient fallback akışı açıldı
- Doğrulama komutları başarıyla geçti:
  - `flutter analyze`
  - `flutter test apps/student_app`
  - `flutter test apps/admin_console`
  - `flutter build apk --debug`
  - `flutter build web --release`
