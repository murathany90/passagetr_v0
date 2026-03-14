# Faz 11 - Admin AI Content Assistant

## 1. Faz Amaci
`apps/admin_console` icine reading-first AI okuma uretim yardimcisini eklemek; admin kullanicinin draft uretmesi, duzenlemesi, linked word onerilerini cozmesi, taslak kaydetmesi ve yayina almasini mevcut admin content zinciri uzerinden saglamak.

## 2. Kapsam
- `/content/ai-assistant` route'u ve sidebar girisi
- Gemini tabanli edge function ile okuma draft uretimi
- Admin tarafinda editable reading draft, linked word resolution ve question editoru
- `AdminReadingDetail` sozlesmesine question ve AI metadata genisletmesi
- Reading detail RPC ve migration genisletmeleri

## 3. Kapsam Disi
- Kelime AI uretimi
- Gramer AI uretimi
- Parca bazli regenerate akisleri
- Background queue veya async job sistemi
- Student uygulamasinda question tuketimi
- AI onerilerinden sessiz otomatik `words` kaydi olusturma

## 4. Yapilacak Isler
- [ ] Schema / RPC
- [ ] Edge function
- [ ] Domain / data kontratlari
- [ ] Controller / UI
- [ ] Testler ve verification

## 5. Teknik Kararlar
- Yeni AI sayfasi mevcut `AdminContentPage` icine gomulmeyecek; ayri feature route olarak acilacak.
- AI yalniz draft uretir; kalici kayit `AdminContentRepository.upsertReadingDetail(...)` ile yapilir.
- Reading publish modeli `is_published`, `publish_at`, `unpublish_at` ekseninde kalir.
- AI question'lari kaliciya yazilir ama student uygulamasi bu fazda tuketmez.
- Linked word onerileri save/publish oncesi mevcut `words` katalougundan secilerek cozulecek veya silinecek.
- `reading_passages.ai_generated` ve `reading_passages.ai_generation_meta` alanlari AI kaynak izini tasir.

## 6. Bagimliliklar
- Faz 05 admin CMS icerik operasyonlari
- Faz 05.5 admin hardening
- `admin_get_reading_detail` / `admin_upsert_reading_detail` RPC zinciri
- Supabase auth + `current_app_role()` RBAC kontrolu

## 7. Riskler
- Gemini cevabinin invalid JSON veya eksik alan donmesi function tarafinda kontrollu handle edilmelidir.
- Reading detail sozlesmesindeki genisleme eski editor akislarini bozarsa hem AI hem manuel okuma editoru etkilenir.
- `reading_passage_questions` icin content change trigger'i eklenmezse sync/version davranisi eksik kalir.
- Linked word resolution UX'i kotu kurulursa admin save/publish blokajinin nedeni anlasilmaz hale gelir.

## 8. Test ve Kabul Kriterleri
- `/content/ai-assistant` route'u acilir ve sidebar'da `AI Asistan` gorunur.
- Edge function admin/developer rolunde calisir; DB'ye kalici kayit yazmaz.
- AI draft editable `AdminReadingDetail` state'ine maplenir.
- Unresolved linked word varken save/publish bloklanir.
- Reading detail contract'i question ve AI metadata alanlarini tasir.
- `reading_passage_questions` migration ile eklenir.
- `admin_get_reading_detail` ve `admin_upsert_reading_detail` questions + AI metadata alanlarini tasir.
- `flutter analyze apps/admin_console packages/shared_domain packages/shared_data` temiz gecer.
- Ilgili widget, controller, repository ve edge function testleri gecer.

## 9. Ilerleme Durumu
- Durum: Planlandi
- Son guncelleme: 2026-03-13

## 10. Tamamlananlar / Notlar
- Faz dosyasi olusturuldu.
- Ozellik reading-first ve mevcut admin content persistence zinciriyle uyumlu olacak sekilde sabitlendi.
- Student uygulamasinda yeni AI yuzeyi acilmamasi ve `service_role` anahtarinin istemciye tasinmamasi bu faz icin sabit kural olarak korundu.
