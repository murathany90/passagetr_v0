A?a??daki dosyalar? birincil kaynak olarak kabul et:

1. `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
2. `DATABASE_SCHEMA.md`
3. `docs/ui_tasarim/` alt?ndaki web ve android ekranlar?
4. `docs/phases/` alt?ndaki faz ?al??ma dosyalar?

Bu g?revde senden istenen ?ey, PASSAGETR v2 i?in uygulanabilir bir teknik ??kt? ve kontroll? faz uygulama ak??? ?retmektir. Bu repo greenfield de?ildir; kontroll? yeniden yaz?m reposudur.

# G?rev ?er?evesi

- Flutter d??? frontend stack ?nerme.
- Supabase ana backend olarak kalacak.
- Android offline-first, web remote-first olacak.
- v1 veri domainleri korunacak ve migration ile evrilecek.
- `main` v1 ar?iv dal?d?r.
- Aktif geli?tirme `v2-rewrite-foundation` ?izgisinde ilerler.
- Ayn? repo i?inde iki uygulama vard?r:
  - `apps/student_app`
  - `apps/admin_console`
- Her geli?tirme faz bazl? ilerleyecek; do?rudan rastgele feature implementasyonu yap?lmayacak.

# Faz Bazl? ?al??ma Kural?

Her yeni faz i?in ?nce `docs/phases/` alt?nda bir ?al??ma dosyas? olu?tur veya mevcut faz dosyas?n? g?ncelle.

Dosya ad? kural?:

- `phase_0a_dokuman_sonlandirma.md`
- `phase_0b_branch_reset.md`
- `phase_0c_workspace_bootstrap.md`
- `phase_1_foundation_auth_rbac.md`
- `phase_2_mobile_offline_data.md`
- ...

Her faz dosyas?nda ?u ba?l?klar zorunludur:

1. Faz Amac?
2. Kapsam
3. Kapsam D???
4. Yap?lacak ??ler
5. Teknik Kararlar
6. Ba??ml?l?klar
7. Riskler
8. Test ve Kabul Kriterleri
9. ?lerleme Durumu
10. Tamamlananlar / Notlar

?al??ma kural?:

- ?nce ilgili faz dosyas?n? olu?tur.
- Yap?lacak i?leri madde madde yaz.
- Uygulama s?ras?nda bu dosyay? ya?ayan dok?man olarak g?ncelle.
- Her tamamlanan i? maddesini dosya ?zerinde i?le.
- Faz bitmeden sonraki faza ge?me.
- Faz sonunda k?sa sonu? ve kalan riskleri ayn? dosyaya yaz.

# Zorunlu Kararlar

??kt?nda ?u kararlar? a??k?a sabitle:

- korunacak v1 domainleri
- v1 -> v2 schema evolution yakla??m?
- workspace klas?r a?ac?
- shared paketlerin sorumluluklar?
- offline sync ak???
- web remote-first veri okuma stratejisi
- RBAC + RLS modeli
- admin CMS kapsam?
- ilk 3 sprint backlog'u
- ilk migration listesi
- hangi faz dosyas?n?n olu?turulaca?? / g?ncellenece?i

# Uygulanamaz ?neri Yasaklar?

- React / Next.js / farkl? frontend stack ?nerme
- service role key'i istemciye ta??ma
- web build'e a??r local SQLite asset g?mme
- v1 veri modelini yok sayan s?f?rdan ?ema ?nerisi ?retme
- ?daha sonra karar verilir? gibi belirsiz ?neriler b?rakma
- faz dosyas? olu?turmadan do?rudan implementasyon plan? bitmi? gibi davranma

# ??kt? Format?

??kt? mutlaka ?u ba?l?klarda gelsin:

1. Karar ?zeti
2. v1'den Korunacak Domainler
3. v2 Workspace A?ac?
4. Schema Evolution Plan?
5. Offline-First ve Sync Ak???
6. Web Remote-First Stratejisi
7. RBAC ve RLS Tasar?m?
8. Admin CMS Tasar?m?
9. ?lk 10 Migration
10. ?lk 3 Sprint ve ?lk 15 Geli?tirme G?revi
11. Faz ?al??ma Dosyas? Plan?
12. Riskler ve Varsay?mlar

# Kalite Kriteri

- ??kt? teori de?il, uygulanabilir olmal?.
- Dosya a?ac?, migration s?ras? ve sprint kapsam? net olmal?.
- Varsay?m yapt?ysan a??k?a ?Varsay?m? diye i?aretle.
- Roadmap ile ?eli?me; roadmap ana karar kayna??d?r.
- README metnini tekrar etme; onu modern mimari gereksinimlere d?n??t?r.
- Her faz i?in hangi `.md` dosyas?n?n kullan?laca?? a??k olmal?.
- Faz biti?inde ?al??ma dosyas? g?ncelleme kural? unutulmamal?.

# Ton

Teknik, k?sa, karar odakl? ve implementer i?in do?rudan kullan?labilir.

# Oturum Kapan??? ??in ?nemli Bilgiler

- Bu repo greenfield de?il; v1'den kontroll? rewrite yap?l?yor.
- Ar?iv etiketi: `v1-archive-2026-03-08`
- Aktif ?al??ma dal?: `v2-rewrite-foundation`
- Birincil kaynaklar:
  - `docs/PASSAGETR_v2_Faz_Bazli_Gelistirme_Yol_Haritasi.md`
  - `DATABASE_SCHEMA.md`
  - `docs/ui_tasarim/`
  - `supabase/`
  - `docs/phases/`
- v1 uygulama implementasyonu bu branch'te bilerek temizlendi; geri getirme veya refactor etme yakla??m? kullanma.
- Yeni workspace topolojisi:
  - `apps/student_app`
  - `apps/admin_console`
  - `packages/shared_core`
  - `packages/shared_domain`
  - `packages/shared_data`
  - `packages/shared_ui`
- Web stratejisi: `remote-first + TTL cache + lazy load`
- Android stratejisi: `offline-first + Drift + outbox + delta sync`
- Supabase ana veri kayna??d?r; `service_role` istemciye asla g?m?lmez.
- Sonraki ilk teknik hedef:
  - `apps/student_app` i?inde Faz 1 foundation + auth + RBAC iskeletini a?mak
  - shared paketlerin s?zle?melerini geni?letmek
  - schema evolution ve migration-first ?al??mak
- Tek app'lik eski root Flutter yap?s?na geri d?nme; bundan sonra t?m yeni geli?tirme monorepo d?zeninde ilerleyecek.
