Aşağıdaki dosyaları birincil kaynak olarak kabul et:

1. `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
2. `DATABASE_SCHEMA.md`
3. `docs/ui_tasarim/` altındaki web ve android ekranları
4. `docs/phases/` altındaki faz çalışma dosyaları

Bu repo greenfield değildir. PASSAGETR v2, v1 veritabanı ve domainlerini koruyan kontrollü yeniden yazım reposudur.

# Görev Çerçevesi

- Flutter dışı frontend stack önerme.
- Supabase ana backend olarak kalacak.
- Android offline-first, web remote-first olacak.
- v1 veri domainleri korunacak ve migration ile evrilecek.
- `main` v1 arşiv dalıdır.
- Aktif geliştirme `v2-rewrite-foundation` dalında ilerler.
- Aynı repo içinde iki uygulama vardır:
  - `apps/student_app`
  - `apps/admin_console`

# Faz Bazlı Çalışma Kuralı

- Her yeni faz için önce `docs/phases/` altında faz dosyası oluştur veya mevcut olanı güncelle.
- Faz dosyası oluşturmadan doğrudan koda geçme.
- Uygulama sırasında faz dosyasını yaşayan doküman olarak işle.
- Tamamlanan her iş maddesini dosya üzerinde işaretle.
- Faz bitmeden sonraki faza geçme.

Her faz dosyasında şu başlıklar zorunludur:

1. Faz Amacı
2. Kapsam
3. Kapsam Dışı
4. Yapılacak İşler
5. Teknik Kararlar
6. Bağımlılıklar
7. Riskler
8. Test ve Kabul Kriterleri
9. İlerleme Durumu
10. Tamamlananlar / Notlar

# Zorunlu Kararlar

Çıktında şu kararları açıkça sabitle:

- korunacak v1 domainleri
- v1 -> v2 schema evolution yaklaşımı
- workspace klasör ağacı
- shared paketlerin sorumlulukları
- offline sync akışı
- web remote-first veri okuma stratejisi
- RBAC + RLS modeli
- admin CMS kapsamı
- ilk 3 sprint backlog'u
- ilk migration listesi
- hangi faz dosyasının oluşturulacağı veya güncelleneceği

# Uygulanamaz Öneri Yasakları

- React / Next.js / farklı frontend stack önerme
- service role key'i istemciye taşıma
- web build'e ağır local SQLite asset gömme
- v1 veri modelini yok sayan sıfırdan şema önerisi üretme
- “daha sonra karar verilir” gibi belirsiz öneriler bırakma
- faz dosyası oluşturmadan doğrudan implementasyon planı bitmiş gibi davranma

# Çıktı Formatı

1. Karar Özeti
2. v1'den Korunacak Domainler
3. v2 Workspace Ağacı
4. Schema Evolution Planı
5. Offline-First ve Sync Akışı
6. Web Remote-First Stratejisi
7. RBAC ve RLS Tasarımı
8. Admin CMS Tasarımı
9. İlk 10 Migration
10. İlk 3 Sprint ve İlk 15 Geliştirme Görevi
11. Faz Çalışma Dosyası Planı
12. Riskler ve Varsayımlar

# Kalite Kriteri

- Çıktı teori değil, uygulanabilir olmalı.
- Dosya ağacı, migration sırası ve sprint kapsamı net olmalı.
- Varsayım yaptıysan açıkça “Varsayım” diye işaretle.
- Roadmap ile çelişme; roadmap ana karar kaynağıdır.
- README metnini tekrar etme.
- Her faz için hangi `.md` dosyasının kullanılacağı açık olmalı.

# Ton

Teknik, kısa, karar odaklı ve implementer için doğrudan kullanılabilir.

# Oturum Kapanışı İçin Önemli Bilgiler

- Bu repo greenfield değil; v1'den kontrollü rewrite yapılıyor.
- Arşiv etiketi: `v1-archive-2026-03-08`
- Aktif çalışma dalı: `v2-rewrite-foundation`
- Birincil kaynaklar:
  - `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
  - `DATABASE_SCHEMA.md`
  - `docs/ui_tasarim/`
  - `supabase/`
  - `docs/phases/`
- v1 uygulama implementasyonu bu branch'te bilerek temizlendi; geri getirme veya refactor etme yaklaşımı kullanma.
- Yeni workspace topolojisi:
  - `apps/student_app`
  - `apps/admin_console`
  - `packages/shared_core`
  - `packages/shared_domain`
  - `packages/shared_data`
  - `packages/shared_ui`
- Web stratejisi: `remote-first + TTL cache + lazy load`
- Android stratejisi: `offline-first + Drift + outbox + delta sync`
- Supabase ana veri kaynağıdır; `service_role` istemciye asla gömülmez.
- Sonraki ilk teknik hedef:
  - `apps/student_app` içinde Faz 1 foundation + auth + RBAC iskeletini açmak
  - shared paketlerin sözleşmelerini genişletmek
  - schema evolution ve migration-first çalışmak
- Tek app'lik eski root Flutter yapısına geri dönme; bundan sonra tüm yeni geliştirme monorepo düzeninde ilerleyecek.
