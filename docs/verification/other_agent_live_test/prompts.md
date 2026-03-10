# Other Agent Prompts for Live UI and Production Testing

Bu dosya, baska bir agente verilecek iki ayri ayrintili promptu icerir. Bu promptlar sonucunda agent kod degistirmeyecek; yalnizca test yapacak, kanit toplayacak ve markdown raporlari uretecek.

## Prompt 1: Browser + Emulator Live Test Execution

```text
Sen bu IDE icinde calisan bagimsiz bir QA / product validation agentsin.

Gorevin, PASSAGETR v2 canli sistemini browser ve Android emulator kullanarak ayrintili test etmektir. Kod degistirme, deploy etme veya env degistirme. Yalnizca test yap, kanit topla ve markdown raporu uret.

Once su dosyayi oku ve birebir uygula:
- `docs/verification/other_agent_live_test/README.md`

Test kapsaminda kullanacagin production URL'ler:
- `https://passagetr-fef48.web.app`
- `https://passagetr-fef48.web.app/profile`
- `https://passagetr-admin.web.app`
- `https://passagetr-admin.web.app/login`

Test hesaplari:
- Ortak sifre: `PassageTR#2026!`
- `phase1.free@passagetr.dev`
- `phase1.pro@passagetr.dev`
- `phase1.admin@passagetr.dev`
- `phase1.developer@passagetr.dev`

Kullanman gereken kaynaklar:
- `docs/ui_tasarim/`
- `docs/phases/`
- `env/app.web.prod.json`
- Canli production siteleri

Zorunlu gorevler:
1. Browser uzerinde student web production smoke yap.
2. Browser uzerinde admin web production smoke yap.
3. Android emulator uzerinde student app akislarini test et.
4. UI parity kontrolu yap.
5. Her hata icin ekran goruntusu ve yeniden uretme adimi topla.
6. Browser console ve network failure kontrolu yap.
7. Student app icindeki admin launcher davranisini test et.
8. Free, PRO ve Admin kullanicilarla en az temel login/gorunurluk kontrolu yap.

Test sonunda su dosyayi guncelleyerek yaz:
- `docs/verification/other_agent_live_test/results.md`

Bu markdown dosyasi su bolumleri icermelidir:
1. Test kapsami
2. Kullanilan ortamlar
3. Test edilen URL ve hesaplar
4. Gecen senaryolar
5. Basarisiz senaryolar
6. Bug listesi
7. UI parity bulgulari
8. Riskler
9. Genel sonuc

Tum ekran goruntuleri su klasore kaydedilmelidir:
- `docs/verification/other_agent_live_test/`

Kurallar:
- Kod degistirme.
- Git commit atma.
- Deploy etme.
- Uydurma test sonucu yazma.
- Gormedigin bir davranisi gormus gibi yazma.
- Bir bug kritik ise acikca `kritik` diye isaretle.

Beklenen ton:
- Teknik
- Kisa
- Kanita dayali
- Maddeler halinde
```

## Prompt 2: Product Improvement and Follow-up Recommendations

```text
Sen bu IDE icinde calisan bagimsiz bir product QA ve UX review agentsin.

Gorevin, once mevcut test raporunu okuyup sonra repo baglamina gore uygulanabilir iyilestirme onerileri cikarmaktir. Kod degistirme. Yalnizca analiz ve oneriler uret.

Mutlaka su dosyalari oku:
- `docs/verification/other_agent_live_test/README.md`
- `docs/verification/other_agent_live_test/results.md`
- `docs/ui_tasarim/`
- `docs/phases/`
- `docs/ui_audit/figma_style_dictionary.md`
- `docs/ui_audit/student_app_gap_analysis.md`

Amacin:
- Test raporundaki bulgulari onceliklendirmek
- UI/UX, production kalite, responsive, admin panel, student akislari ve test kapsami icin uygulanabilir oneriler yazmak
- Bu onerilerin benim tarafimdan uygulanabilecek sekilde net olmasini saglamak

Test raporunu tekrar etme. Onu sentezle ve somut aksiyonlara cevir.

Su dosyayi guncelleyerek yaz:
- `docs/reports/other_agent_product_improvement_suggestions.md`

Bu markdown dosyasi su bolumleri icermelidir:
1. Yonetici ozeti
2. En kritik 10 iyilestirme onerisi
3. UI/UX onerileri
4. Student web/mobile onerileri
5. Admin web onerileri
6. Production smoke ve regression test kapsami onerileri
7. Performans / cache / responsive onerileri
8. Onceliklendirilmis backlog

Her oneride su format kullan:
- Baslik
- Problem
- Kullanici etkisi
- Oncelik: `P0`, `P1`, `P2`
- Onerilen cozum
- Varsa etkilenen ekran veya route

Kurallar:
- Kod degistirme.
- Faz disi stack onermeme.
- React / Next.js gibi baska frontend stack onermeme.
- Supabase ana backend kararini bozma.
- Ayrik `student_app` ve `admin_console` mimarisini yok sayma.
- Belirsiz ve genel gecer ifadeler yazma.

Beklenen ton:
- Teknik
- Karar odakli
- Kisa ama uygulanabilir
```
