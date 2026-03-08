Aþaðýdaki dosyalarý birincil kaynak olarak kabul et:

1. `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
2. `DATABASE_SCHEMA.md`
3. `docs/ui_tasarim/` altýndaki web ve android ekranlarý

Bu görevde senden istenen þey, PASSAGETR v2 için uygulanabilir bir teknik çýktý üretmektir. Bu repo greenfield deðildir; kontrollü yeniden yazým reposudur.

# Görev Çerçevesi

- Flutter dýþý frontend stack önerme.
- Supabase ana backend olarak kalacak.
- Android offline-first, web remote-first olacak.
- v1 veri domainleri korunacak ve migration ile evrilecek.
- `main` v1 arþiv dalýdýr.
- Aktif geliþtirme `v2-rewrite-foundation` çizgisinde ilerler.
- Ayný repo içinde iki uygulama vardýr:
  - `apps/student_app`
  - `apps/admin_console`

# Zorunlu Kararlar

Çýktýnda þu kararlarý açýkça sabitle:

- korunacak v1 domainleri
- v1 -> v2 schema evolution yaklaþýmý
- workspace klasör aðacý
- shared paketlerin sorumluluklarý
- offline sync akýþý
- web remote-first veri okuma stratejisi
- RBAC + RLS modeli
- admin CMS kapsamý
- ilk 3 sprint backlog'u
- ilk migration listesi

# Uygulanamaz Öneri Yasaklarý

- React / Next.js / farklý frontend stack önerme
- service role key'i istemciye taþýma
- web build'e aðýr local SQLite asset gömme
- v1 veri modelini yok sayan sýfýrdan þema önerisi üretme
- “daha sonra karar verilir” gibi belirsiz öneriler býrakma

# Çýktý Formatý

Çýktý mutlaka þu baþlýklarda gelsin:

1. Karar Özeti
2. v1'den Korunacak Domainler
3. v2 Workspace Aðacý
4. Schema Evolution Planý
5. Offline-First ve Sync Akýþý
6. Web Remote-First Stratejisi
7. RBAC ve RLS Tasarýmý
8. Admin CMS Tasarýmý
9. Ýlk 10 Migration
10. Ýlk 3 Sprint ve Ýlk 15 Geliþtirme Görevi
11. Riskler ve Varsayýmlar

# Kalite Kriteri

- Çýktý teori deðil, uygulanabilir olmalý.
- Dosya aðacý, migration sýrasý ve sprint kapsamý net olmalý.
- Varsayým yaptýysan açýkça “Varsayým” diye iþaretle.
- Roadmap ile çeliþme; roadmap ana karar kaynaðýdýr.
- README metnini tekrar etme; onu modern mimari gereksinimlere dönüþtür.

# Ton

Teknik, kýsa, karar odaklý ve implementer için doðrudan kullanýlabilir.

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

