# Gemini UI Parity Prompt Set

Bu dosya, IDE icindeki Gemini ajanina verilecek iki ayri promptu icerir.
Konumu: `docs/ui_audit/ai_collab/`

- Prompt 1: Figma + mevcut kod parity analizi
- Prompt 2: Uygulama yaptirmak yerine Codex icin geri bildirim ve teknik yonlendirme uretme

Kullanim sirasi:
1. Once Prompt 1'i calistir.
2. Uretilen analiz ve raporlari kontrol et.
3. Ardindan Prompt 2'yi calistir.
4. Prompt 2 sonucunda uretilen geri bildirim raporunu bana ver.
5. Uygulamayi ben ara faz olarak ele alip kodu buna gore ilerletecegim.

Figma token kaynagi:
- Proje kokunde `.env.figma.local` dosyasi bulunur.
- Bu dosyada `FIGMA_ACCESS_TOKEN=...` tanimlidir.
- Gemini ajani MCP veya baska entegrasyon kurarken token'i bu dosyadan yuklemeli, prompt icine duz metin olarak yazmamalidir.

Prompt vermeden once PowerShell oturumunda su komutu calistir:

```powershell
. .\scripts\load_figma_env.ps1
```

Kontrol komutu:

```powershell
echo $env:FIGMA_ACCESS_TOKEN
```

---

## Prompt 1: Figma + Mevcut Kod Parity Analizi

```text
Sen ust duzey bir Flutter gelistiricisi ve sistem mimarisisin.

Amacin, bu repodaki mevcut Flutter UI ile Figma tasarimi arasinda detayli parity analizi yapmak. Bu ilk gorevde KESINLIKLE kod degistirme. Yalnizca analiz, fark listesi, ekran eslemesi ve uygulanabilir implementasyon plani uret.

Repo baglami:
- Bu repo monorepo yapisinda.
- Ana son kullanici uygulamasi: `apps/student_app`
- Ayrik admin uygulamasi: `apps/admin_console`
- Ortak UI kati: `packages/shared_ui`
- Ortak temel tipler: `packages/shared_core`
- Veri/repository kati: `packages/shared_data`
- Faz dokumanlari: `docs/phases/`
- Taslak ekranlar: `docs/ui_tasarim/`
- Bu repo greenfield degildir; mevcut calisan mimari korunmalidir.
- Flutter disi stack onerme.
- Is mantigini, repository'leri, auth akislarini, provider yapisini bu asamada degistirme.
- Ilk analiz kapsami yalnizca `apps/student_app` olsun.

Oncelikli route ve ekranlar:
- `/`
- `/words`
- `/readings`
- `/readings/:id`
- `/grammar`
- `/profile`

Figma bilgisi:
- Figma file id: `Adq9rlxsgNczDRwVUY2RU1`
- Figma access token'i prompt icine duz metin olarak gommek yerine environment variable olarak kullan.
- Token kaynagi proje kokundeki `.env.figma.local` dosyasidir.
- Bu dosyadaki `FIGMA_ACCESS_TOKEN` degerini yukleyip kullan.
- Eger IDE ajani MCP ile Figma baglantisi kurabiliyorsa onu kullan.
- Eger MCP kullanilamiyorsa bunu acikca raporla ve fallback'e gec:
  - Figma REST API
  - veya `docs/ui_tasarim/` ekranlari

Adim 1: Figma baglantisini dogrula
- Bu IDE ajaninin MCP destekleyip desteklemedigini kontrol et.
- Uygun config dosyasi gerekiyorsa bul veya olustur.
- Token'i prompt icine veya config'e duz metin olarak yazma; proje kokundeki `.env.figma.local` dosyasindan okuyup environment variable uzerinden kullan.
- Baglanti basariliysa bunu kanitla.
- Baglanti basarisizsa uydurma basari raporu verme.

Adim 2: Figma tasarim analizi
- Verilen Figma dosyasini analiz et.
- Asagidaki stil sozlugunu cikar:
  - renkler
  - typography
  - spacing
  - border radius
  - shadows
  - navigation yapisi
  - kart, liste ve detail layout kaliplari
- Auto Layout karsiliklarini Flutter widget'larina cevir:
  - Row
  - Column
  - Stack
  - Wrap
  - LayoutBuilder breakpoint stratejisi
- Ciktiyi `docs/ui_audit/figma_style_dictionary.md` dosyasina yaz.

Adim 3: Mevcut Flutter UI analizi
- Su alanlari oku:
  - `apps/student_app/lib/src/app/`
  - `apps/student_app/lib/src/features/`
  - `packages/shared_ui/lib/`
- Widget hiyerarsisini, route yapisini, theme ve token kullanimini, reusable component yapisini cikar.
- Mumkunse mevcut uygulamanin ekran goruntulerini uret ve `artifacts/ui_parity/current/` altina kaydet.

Adim 4: Figma vs mevcut UI gap analysis
- Her ekran icin su tabloyu uret:
  - Figma ekrani
  - mevcut route
  - mevcut dosya
  - parity durumu
  - eksik bilesenler
  - yanlis spacing, typography veya token kullanimi
  - navigation farklari
  - etkilenmesi gereken dosyalar
- Ciktiyi `docs/ui_audit/student_app_gap_analysis.md` dosyasina yaz.

Adim 5: Guvenli implementasyon plani
- Henuz kod degistirme.
- Yalnizca uygulanabilir plan uret.
- Plan sunlari icersin:
  - hangi faz dosyasinin guncellenecegi
  - hangi shared UI bilesenlerinin revize edilecegi
  - hangi ekranlarin hangi sirayla ele alinacagi
  - hangi dosyalarin yalniz UI katmaninda degisecegi
  - hangi logic dosyalarina dokunulmayacagi
  - test ve build dogrulama adimlari
- Ciktiyi `docs/ui_audit/student_app_ui_execution_plan.md` dosyasina yaz.

Zorunlu kurallar:
- Kod degisikligi yapma.
- Faz dosyasini guncellemeden implementasyona gecme.
- Is mantigini degistirme.
- Uydurma MCP baglanti basarisi raporu verme.
- Repo yapisini `lib/` diye genelleme; gercek monorepo path'lerini kullan.
- `docs/ui_tasarim` ile Figma arasinda celiski gorursen bunu acikca raporla.

Final cikti formatin:
1. MCP baglanti durumu
2. Figma stil sozlugu ozeti
3. Ekran bazli gap analysis ozeti
4. Riskler
5. Onerilen implementasyon sirasi
6. Uretilen dosyalarin listesi
```

---

## Prompt 2: Codex Icin UI Uygulama Geri Bildirimi

```text
Sen ust duzey bir Flutter UI reviewer ve sistem mimarisisin.

Bu gorevde KESINLIKLE dogrudan kod implementasyonu yapma. Amacin, mevcut repo durumu, Figma analizi ve taslak ekranlar uzerinden Codex'in uygulayacagi UI parity calismasi icin teknik geri bildirim, risk analizi ve net bir uygulama rehberi uretmek.

Baglam:
- Repo monorepo yapisinda.
- Son kullanici urunu: `apps/student_app`
- Admin urunu: `apps/admin_console`
- Ortak UI kati: `packages/shared_ui`
- Faz dokumanlari: `docs/phases/`
- Taslak ekranlar: `docs/ui_tasarim/`
- Figma parity kaynaklari Prompt 1 sonucunda analiz edilmistir.
- Kod yazma veya refactor yapma gorevi sende degil.
- Uygulamayi Codex yapacak.
- Senin cikti gorevin, Codex'in ara faz olarak uygulayacagi degisiklikler icin net geri bildirim vermek.

Okunacak kaynaklar:
- `docs/ui_audit/figma_style_dictionary.md`
- `docs/ui_audit/student_app_gap_analysis.md`
- `docs/ui_audit/student_app_ui_execution_plan.md`
- `docs/phases/phase_03_cekirdek_ogrenme_modulleri.md`
- `docs/phases/phase_04_okuma_ceviri_gramer.md`
- `apps/student_app/lib/src/`
- `packages/shared_ui/lib/src/`

Gorevin:
1. Mevcut kod ile Figma arasindaki en kritik parity aciklarini yeniden dogrula.
2. Codex'in hangi sirayla ilerlemesi gerektigini ekran bazli ve dosya bazli netlestir.
3. Su basliklarda teknik geri bildirim raporu uret:
   - shell ve navigation
   - typography ve spacing
   - renk/token uyumsuzluklari
   - kart/list/detail component farklari
   - responsive davranis
   - dokunulmamasi gereken logic alanlari
   - olasi regression riskleri
4. Her ekran icin "uygulanacak", "dokunulmayacak", "riskli" listesi cikar.
5. Faz 3, Faz 4 ve gerekiyorsa sonraki fazlar icin Codex'e ara faz mantigiyla uygulanabilir sira ver.

Zorunlu kurallar:
- Kod degistirme.
- Otomatik refactor yapma.
- Dosya uretmek serbest, ama yalnizca rapor ve geri bildirim dosyasi uret.
- Is mantigini degistirmeyi onerme.
- Flutter disi stack onerme.
- `docs/ui_tasarim` ve Figma parity'sine sadik kal.
- "Daha sonra karar verilir" gibi belirsiz ifade kullanma.

Uretilecek dosya:
- `docs/ui_audit/ai_collab/CODEX_UI_IMPLEMENTATION_FEEDBACK.md` dosyasini yaz.

Raporun su bolumleri zorunlu:
1. Ozet
2. En kritik 10 parity farki
3. Dosya bazli mudahale plani
4. Dokunulmayacak logic alanlari
5. Regression riskleri
6. Codex icin onerilen uygulama sirasi
7. Faz gecis oneri notlari

Final mesajinda yalnizca sunlari ver:
- `docs/ui_audit/ai_collab/CODEX_UI_IMPLEMENTATION_FEEDBACK.md` olusturuldu mu
- En kritik 5 bulgu
- Codex'in once hangi ekranla devam etmesi gerektigi
```
