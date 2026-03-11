# Profile / Auth / Sidebar Stabilization Plan

## Amaç

Bu plan, student web ve APK tarafında profil, kimlik doğrulama ve sol sidebar davranışlarını ürün beklentisine getirmek için hazırlanmıştır.

Kapsam:
- Web sol sidebar'a giriş durumuna bağlı `Çıkış Yap` aksiyonu eklemek
- Profil sayfasındaki `Hesabı Yönet` ve `Ayarlar` akışlarını gerçek işlevine kavuşturmak
- Kullanıcı adı değiştirme için en basit ama kalıcı akışı eklemek
- Profil sayfasındaki `Giriş Yap` ve `Kayıt Ol` akışlarını görünür, doğrulanmış ve güvenilir hale getirmek
- Web ve APK tarafında aynı davranışı sağlamak

## Doğrulanan Mevcut Durum

### 1. Sol sidebar

Mevcut shell, anonim kullanıcı için altta `Giriş`, giriş yapmış kullanıcı için `Profil` gösteriyor; fakat sidebar içinde ayrı bir `Çıkış Yap` aksiyonu yok.

İlgili dosya:
- `apps/student_app/lib/src/features/common/page_parts.dart`

### 2. Profil sayfası

Profil sayfası iki moda ayrılmış durumda:
- anonim kullanıcı için auth yüzeyi
- giriş yapmış kullanıcı için profil yüzeyi

Ancak `Hesabı Yönet` gerçek hesap yönetimi yapmıyor; mevcut akış tekrar auth sheet açıyor.

İlgili dosya:
- `apps/student_app/lib/src/features/profile/profile_page.dart`

### 3. Ayarlar butonu

Hero alanındaki `Ayarlar` butonu teknik olarak bir modal açıyor, fakat kullanıcı beklentisindeki "hesap ayarları" yerine hızlı ayarlar paneli açıyor.

Eksikler:
- kullanıcı adı değiştirme yok
- kaydet akışı yok
- loading / success / error state yok
- ayarların bir kısmı kalıcı değil

İlgili dosya:
- `apps/student_app/lib/src/features/profile/profile_page.dart`

### 4. Kullanıcı adı değiştirme

Şu an veri katmanında kullanıcı adı güncelleyen bir repository metodu yok.

Mevcut auth yüzeyi yalnızca:
- `signInWithEmail`
- `signUpWithEmail`
- `upgradeAnonymousWithEmail`
- `refreshSession`
- `signOut`

sunuyor.

İlgili dosyalar:
- `packages/shared_domain/lib/src/repositories/auth_repository.dart`
- `packages/shared_data/lib/src/auth/foundation_auth_repository.dart`
- `apps/student_app/lib/src/core/student_access_controller.dart`

### 5. Giriş yap / kayıt ol

Profil sayfasındaki auth sheet içinde `Giriş Yap` ve `Kayıt Ol` callback'leri bağlı; yani butonlar tamamen boş değil.

Sorun daha çok UX ve operasyon tarafında:
- form validation zayıf
- loading state yok
- hangi işlem başarılı oldu net değil
- kayıt sonrası beklenen sonraki adım görünür değil
- hata mesajları kullanıcı dilinde ve bağlama göre yeterince açıklayıcı değil
- auth yüzeyi "hesap yönetimi" ile karışmış durumda

İlgili dosya:
- `apps/student_app/lib/src/features/profile/profile_page.dart`

## Hedef Ürün Davranışı

### Web

- Sol sidebar ana navigasyonda içerik menüleri kalacak.
- Sidebar alt bölümde:
  - anonim kullanıcı için `Giriş`
  - giriş yapmış kullanıcı için `Profil`
  - giriş yapmış kullanıcı için ayrıca `Çıkış Yap`
- `Çıkış Yap` route değil, doğrudan aksiyon olacak.

### APK / mobil

- Alt navigasyon anonim kullanıcıda `Giriş`, giriş yapmış kullanıcıda `Profil` göstermeye devam edecek.
- Mobilde `Çıkış Yap` profil ekranı içinden ve hesap yönetimi panelinden erişilebilir kalacak.
- Web ile aynı auth ve profil mantığı kullanılacak.

### Profil sayfası

- Anonim kullanıcı:
  - üstte kısa bilgilendirme
  - altta net bir auth formu
  - ayrı `Giriş Yap` ve `Kayıt Ol` akışı
  - anonim hesap varsa `Anonim Hesabı Yükselt`
- Giriş yapmış kullanıcı:
  - profil hero
  - kullanıcı adı alanı
  - hesap yönetimi kartı
  - ayarlar kartı
  - giriş/kayıt formu görünmeyecek

### Ayarlar

- `Ayarlar` butonu hızlı ayarlar yerine gerçek `Profil Ayarları` yüzeyi açacak.
- Bu yüzeyde ilk turda yalnızca:
  - kullanıcı adı
  - tema
  - dil
  - oturumu yenile
  - çıkış yap
  olacak.

## P0

### P0-1 Web sidebar'a `Çıkış Yap` taşı

Amaç:
- Webde çıkış işlemi profil sayfasına girmeden yapılabilsin.

Yapılacaklar:
- `page_parts.dart` içinde sidebar alt bölümünü route item ve action item olarak ikiye ayır.
- `Profil` veya `Giriş` item'ının altına sadece `accessContext.hasIdentifiedProfile == true` iken görünen `Çıkış Yap` aksiyonu ekle.
- Bu aksiyon `StudentAccessController.signOut()` çağıracak.
- Başarı sonrası kullanıcı `/profile` yerine `/` veya mevcut güvenli public route'a yönlendirilecek.
- Snackbar ile sonuç gösterilecek.

Kabul kriteri:
- Webde kayıtlı kullanıcı giriş yaptığında sidebar altında `Çıkış Yap` görünür.
- Anonim kullanıcıda görünmez.
- Tıklanınca session kapanır, UI `Giriş` moduna döner.

Ana dosyalar:
- `apps/student_app/lib/src/features/common/page_parts.dart`
- `apps/student_app/lib/src/core/student_access_controller.dart`

### P0-2 `Hesabı Yönet` akışını auth sheet olmaktan çıkar

Amaç:
- Giriş yapmış kullanıcı için "hesap yönetimi" butonu yeniden giriş paneli açmamalı.

Yapılacaklar:
- Profilde giriş yapmış kullanıcı için ayrı `AccountManagementSheet` veya `ProfileAccountSheet` oluştur.
- Bu sheet içinde:
  - kullanıcı adı düzenleme alanı
  - e-posta bilgisi
  - oturumu yenile
  - çıkış yap
  - plan bilgisi
  yer alacak.
- `Hesabı Yönet` butonu bu yeni sheet'i açacak.
- Anonim kullanıcıda aynı buton auth sheet açmaya devam edecek.

Kabul kriteri:
- Kimlikli kullanıcı `Hesabı Yönet` dediğinde auth formu değil hesap yönetimi yüzeyi açılır.
- Anonim kullanıcı aynı aksiyonda auth yüzeyini görür.

Ana dosya:
- `apps/student_app/lib/src/features/profile/profile_page.dart`

### P0-3 `Ayarlar` butonunu gerçek ilk sürüm ayarlarına bağla

Amaç:
- Kullanıcı beklentisindeki temel ayarlar çalışır hale gelsin.

Yapılacaklar:
- Mevcut `Hızlı Ayarlar` sheet'i `Profil Ayarları` olarak yeniden adlandır.
- İçeriği iki bölüme ayır:
  - Uygulama ayarları: tema, dil
  - Profil ayarları: kullanıcı adı
- Save aksiyonu ekle.
- Kullanıcı adı kaydı başarılı olduğunda hero ve home selamlama alanı güncellensin.
- Tema ve dil seçimi kaydet butonuna bağlı ya da anlık uygulanıp ayrıca persist edilsin.

Kabul kriteri:
- Ayarlar paneli açıldığında kullanıcı adı alanı görünür.
- Kaydet sonrası kullanıcı adı profil hero'da değişir.
- Tema seçimi uygulamaya yansır.

Ana dosyalar:
- `apps/student_app/lib/src/features/profile/profile_page.dart`
- `apps/student_app/lib/src/features/home/home_page.dart`

### P0-4 Kullanıcı adı değiştirme için gerçek data akışı ekle

Amaç:
- "Kullanıcı adı nasıl değişecek?" sorusunu kod seviyesinde çözmek.

Yapılacaklar:
- `AuthRepository` arayüzüne `updateDisplayName({required String displayName})` ekle.
- `StudentAccessController` içine aynı komutu ekle.
- `FoundationAuthRepository` içinde Supabase `updateUser(...)` üzerinden `display_name` metadata güncellemesini yap.
- Başarılı işlemden sonra `refreshSession()` çağrılarak `AccessContext` yenilensin.
- Supabase kapalı preview modunda bu aksiyon kontrollü preview success veya açık hata dönsün; sessiz no-op olmasın.

Teknik not:
- İlk sürüm için kullanıcı adı `user_metadata.display_name` altında tutulacak.
- Ayrı profile tablosu bu fazda zorunlu değil.

Kabul kriteri:
- Kayıtlı kullanıcı kullanıcı adını değiştirir.
- Sayfa yenilenmeden yeni ad profil kartında görünür.
- Session restore sonrasında da ad korunur.

Ana dosyalar:
- `packages/shared_domain/lib/src/repositories/auth_repository.dart`
- `packages/shared_data/lib/src/auth/foundation_auth_repository.dart`
- `apps/student_app/lib/src/core/student_access_controller.dart`

### P0-5 `Giriş Yap` ve `Kayıt Ol` akışlarını ürün seviyesine çıkar

Amaç:
- Butonların yalnız callback bağlı olması yetmez; kullanıcı akışı açık ve güvenilir olmalı.

Yapılacaklar:
- Auth formuna `Form` ve validator ekle.
- E-posta ve şifre boşsa çağrı yapılmasın.
- Butonlar çağrı sırasında loading durumuna geçsin.
- Başarı durumunda:
  - giriş sonrası auth panel kapansın
  - profil modu otomatik yenilensin
  - başarı mesajı net olsun
- kayıt sonrası:
  - anında oturum açıldıysa profil moduna geç
  - onay maili gerekiyorsa kullanıcıya açık bilgi göster
- hata durumunda backend mesajı doğrudan basılmak yerine kullanıcı dostu kopya üret.

Kabul kriteri:
- Boş form ile giriş/kayıt denenemez.
- Kullanıcı işlem sırasında ikinci kez butona basamaz.
- Başarılı giriş sonrası `Giriş` görünümü `Profil` görünümüne döner.

Ana dosyalar:
- `apps/student_app/lib/src/features/profile/profile_page.dart`
- `apps/student_app/lib/src/core/student_access_controller.dart`
- `packages/shared_data/lib/src/auth/foundation_auth_repository.dart`

## P1

### P1-1 Tema ve dil tercihini kalıcı hale getir

Mevcut durum:
- Tema state provider'da tutuluyor.
- Dil yalnız `profile_page.dart` içinde local state.

Yapılacaklar:
- Dil tercihi için app-level provider ekle.
- Tema ve dil tercihini local persistence katmanına yaz.
- App açılışında restore et.

Ana dosyalar:
- `apps/student_app/lib/src/core/student_providers.dart`
- `apps/student_app/lib/src/app/student_app.dart`
- yeni local settings repository / storage dosyaları

### P1-2 Profil ekranı bilgi mimarisini sadeleştir

Yapılacaklar:
- Profil hero, plan kartı, ayarlar ve hesap yönetimi kartları yeniden sıralanacak.
- Aynı aksiyonun birden fazla kartta tekrar etmesi azaltılacak.
- `Planı Gör`, `Hesabı Yönet`, `Ayarlar` çakışan sorumluluklardan arındırılacak.

### P1-3 Web ve mobil davranış tutarlılığını artır

Yapılacaklar:
- Web sidebar ve mobil profil ekranı aksiyonları aynı state modelini kullanacak.
- Sign-out sonrası route davranışı her iki platformda tek kurala bağlanacak.

## P2

### P2-1 Ayrı `Profil Ayarları` ve `Uygulama Ayarları` sayfaları

Bu fazda modal yerine ayrı route'lara geçilebilir:
- `/profile/settings`
- `/profile/account`

Bu adım P0 tamamlandıktan sonra alınmalı.

### P2-2 Hesap işlemleri için daha güçlü güvenlik ve açıklayıcı akışlar

Yapılacaklar:
- şifre değiştirme
- e-posta güncelleme
- işlem öncesi re-auth
- doğrulama uyarıları

Bu maddeler mevcut kullanıcı isteğinin ilk tur kapsamı dışındadır.

## Uygulama Sırası

1. `P0-4` veri katmanı: kullanıcı adı update komutu
2. `P0-2` hesap yönetimi yüzeyi
3. `P0-3` ayarlar paneli sadeleştirme
4. `P0-5` auth form doğrulama ve loading state
5. `P0-1` web sidebar sign-out
6. `P1-1` tema ve dil persistence

Bu sıra doğru çünkü UI'daki `Hesabı Yönet` ve `Ayarlar` akışlarını düzeltmeden önce veri komutunu tanımlamak gerekir.

## Test Planı

### Widget test

- anonymous web sidebar `Giriş` gösterir, `Çıkış Yap` göstermez
- authenticated web sidebar `Profil` ve `Çıkış Yap` gösterir
- `Çıkış Yap` tıklanınca shell anonymous moda döner
- authenticated profilde `Hesabı Yönet` auth sheet değil account sheet açar
- `Ayarlar` panelinde kullanıcı adı alanı görünür
- auth form boş alanlarla submit edilemez
- başarılı giriş sonrası profil hero görünür

### Unit / controller test

- `StudentAccessController.updateDisplayName` başarılı sonuçta access state günceller
- repository `updateDisplayName` success ve failure akışlarını doğru döner

### Entegrasyon doğrulaması

- web canlı build'de sidebar sign-out
- APK emülatörde giriş yap / çıkış yap
- kullanıcı adı değiştir, uygulamayı yeniden aç, adın korunduğunu doğrula

## Riskler

- Supabase build'lerinde `signUp` akışı e-posta doğrulamasına bağlı olabilir; UX metni buna göre ayrılmalı.
- Preview modunda kullanıcı adı güncelleme davranışı açık tanımlanmazsa "çalıştı gibi görünüp kalıcı olmayan" sahte başarı üretir.
- Sidebar'daki sign-out aksiyonu route item mantığıyla karıştırılırsa erişilebilirlik ve state güncellemesi bozulabilir.

## Tamamlanma Tanımı

Bu plan tamamlandığında:
- webde çıkış yap sidebar'dan yapılabilecek
- profilde `Hesabı Yönet` gerçek hesap paneli açacak
- ayarlar butonu kullanıcı adı değişikliğini destekleyecek
- `Giriş Yap` ve `Kayıt Ol` akışları doğrulama, loading ve başarı/hata geri bildirimi ile çalışacak
- web ve APK aynı auth/profil mantığını kullanacak
