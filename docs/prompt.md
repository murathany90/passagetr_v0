Aşağıdaki dosyaları birincil kaynak olarak kabul et:

1. `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
2. `DATABASE_SCHEMA.md`
3. `docs/ui_tasarim/` altındaki web ve android ekranları

Bu görevde senden istenen şey, PASSAGETR v2 için uygulanabilir bir teknik çıktı üretmektir. Bu repo greenfield değildir; kontrollü yeniden yazım reposudur.

# Görev Çerçevesi

- Flutter dışı frontend stack önerme.
- Supabase ana backend olarak kalacak.
- Android offline-first, web remote-first olacak.
- v1 veri domainleri korunacak ve migration ile evrilecek.
- `main` v1 arşiv dalıdır.
- Aktif geliştirme `v2-rewrite-foundation` çizgisinde ilerler.
- Aynı repo içinde iki uygulama vardır:
  - `apps/student_app`
  - `apps/admin_console`

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

# Uygulanamaz Öneri Yasakları

- React / Next.js / farklı frontend stack önerme
- service role key'i istemciye taşıma
- web build'e ağır local SQLite asset gömme
- v1 veri modelini yok sayan sıfırdan şema önerisi üretme
- “daha sonra karar verilir” gibi belirsiz öneriler bırakma

# Çıktı Formatı

Çıktı mutlaka şu başlıklarda gelsin:

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
11. Riskler ve Varsayımlar

# Kalite Kriteri

- Çıktı teori değil, uygulanabilir olmalı.
- Dosya ağacı, migration sırası ve sprint kapsamı net olmalı.
- Varsayım yaptıysan açıkça “Varsayım” diye işaretle.
- Roadmap ile çelişme; roadmap ana karar kaynağıdır.
- README metnini tekrar etme; onu modern mimari gereksinimlere dönüştür.

# Ton

Teknik, kısa, karar odaklı ve implementer için doğrudan kullanılabilir.

# Oturum Kapanisi Icin Onemli Bilgiler

- Bu repo greenfield degil; v1'den kontrollu rewrite yapiliyor.
- Arsiv etiketi: `v1-archive-2026-03-08`
- Aktif calisma dali: `v2-rewrite-foundation`
- Birincil kaynaklar:
  - `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
  - `DATABASE_SCHEMA.md`
  - `docs/ui_tasarim/`
  - `supabase/`
- v1 uygulama implementasyonu bu branch'te bilerek temizlendi; geri getirme veya refactor etme yaklasimi kullanma.
- Yeni workspace topolojisi:
  - `apps/student_app`
  - `apps/admin_console`
  - `packages/shared_core`
  - `packages/shared_domain`
  - `packages/shared_data`
  - `packages/shared_ui`
- Web stratejisi: `remote-first + TTL cache + lazy load`
- Android stratejisi: `offline-first + Drift + outbox + delta sync`
- Supabase ana veri kaynagidir; `service_role` istemciye asla gomulmez.
- Sonraki ilk teknik hedef:
  - `apps/student_app` icinde Faz 1 foundation + auth + RBAC iskeletini acmak
  - shared paketlerin sozlesmelerini genisletmek
  - schema evolution ve migration-first calismak
- Tek app'lik eski root Flutter yapisina geri donme; bundan sonra tum yeni gelistirme monorepo duzeninde ilerleyecek.

