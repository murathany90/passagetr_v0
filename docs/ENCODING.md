# Encoding ve Turkce Karakter Kurallari

Bu repo icin tek gecerli metin kodlamasi `UTF-8 (BOM'suz)` ve satir sonu formati `LF`'dir.

## Sorun Neden Olusuyor?

Turkce karakter bozulmasi genelde dosyanin sonradan yanlis okunmasindan degil, dosyanin daha yazilirken bozulmasindan kaynaklanir.

En sik nedenler:

- PowerShell veya terminal icinden buyuk Turkce metni dogrudan komut string'i olarak yazmak
- Here-string veya ara shell zincirlerinde karakter donusumu yasanmasi
- ANSI / cp1254 iceriklerin fark edilmeden repoya girmesi
- Editorde dosya dogru olsa bile terminal ciktisina bakip yanlis teshis koymak

Not:

- PowerShell konsolu bazen UTF-8 dosyayi ekranda bozuk gosterebilir.
- Esas kontrol byte seviyesinde yapilmalidir; bunun icin `scripts/ensure_utf8.ps1` kullanilir.

## Repo Icindeki Koruma Katmanlari

Bu repo zaten su korumalari tasir:

- [`.editorconfig`](/c:/yazilim_projeler/passagetr_v0/.editorconfig)
- [`.gitattributes`](/c:/yazilim_projeler/passagetr_v0/.gitattributes)
- [`.vscode/settings.json`](/c:/yazilim_projeler/passagetr_v0/.vscode/settings.json)
- [`scripts/ensure_utf8.ps1`](/c:/yazilim_projeler/passagetr_v0/scripts/ensure_utf8.ps1)
- [`.githooks/pre-commit`](/c:/yazilim_projeler/passagetr_v0/.githooks/pre-commit)

Pre-commit hook yalniz "UTF-8 mi?" kontrolu yapmaz; tipik mojibake isaretlerini de yakalar.

## Zorunlu Calisma Kurali

Turkce iceren `.md`, `.txt`, `.json`, `.yml`, `.yaml`, `.ps1`, `.sql` dosyalarinda su kurali uygula:

1. Kucuk duzenlemelerde `apply_patch` kullan.
2. Buyuk metin yazimlarinda yalnizca acik UTF-8 yazimi kullan.
3. Buyuk Turkce metni shell icine yapistirip "tek komutta dosya uretme" yonteminden kacin.

## Guvenli Yazma Yontemleri

### 1. `apply_patch`

Kod ajani tarafinda kucuk ve orta olcekli guvenli duzenleme icin birinci tercih budur.

### 2. UTF-8 yazma scripti

Bu script hedef dosyayi acikca `UTF-8 (BOM'suz)` olarak yazar:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\write_utf8.ps1 -Path docs\prompt.md -InputFile docs\kaynak.md
```

veya:

```powershell
"Merhaba dunya, cgusoiI" | powershell -ExecutionPolicy Bypass -File .\scripts\write_utf8.ps1 -Path docs\ornek.md
```

## Kontrol Komutlari

### Tum repo icin dogrulama

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_utf8.ps1
```

### Gecersiz ANSI/cp1254 dosyalarini UTF-8'e cevirme

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_utf8.ps1 -Fix
```

### Sadece staged dosyalari kontrol etme

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\ensure_utf8.ps1 -StagedOnly
```

## Git Hook Kurulumu

Bu repo icin pre-commit hook yerel olarak bir kez kurulmalidir:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_git_hooks.ps1
```

Bu komut `core.hooksPath` degerini `.githooks` olarak ayarlar.

## Commit Oncesi Kisa Checklist

- Turkce iceren dosyayi shell komut string'i ile uretmedim
- Gerekirse `write_utf8.ps1` kullandim
- `ensure_utf8.ps1` temiz gecti
- Supheli `?`, `?`, `?`, `??`, `?` benzeri icerik yok

## Kural

Bu repoda Turkce dokuman uretirken:

- hizli ama riskli shell yazimi yasak
- acik UTF-8 yazimi zorunlu
- pre-commit kontrolu varsayilan guvenlik agidir
