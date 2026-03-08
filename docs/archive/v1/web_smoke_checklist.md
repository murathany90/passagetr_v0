# Web Smoke Checklist

1. `flutter run -d chrome --dart-define-from-file=env/app.web.json`
2. Splash sonrasi shell acilmali; ilk anda uygulama tamamen blok olmamali.
3. `>= 1200px` genislikte `NavigationRail`, daha dar genisliklerde alt `NavigationBar` gorunmeli.
4. Ana Sayfa masaustunde `Bugunku Egitim` ve `Gunluk Metrikler` iki kolonlu gorunmeli.
5. Kelime sekmesinde masaustunde sol arama paneli ve sag sonuc/paket alani ayni anda gorunmeli.
6. Kelime arama, filtre degisimi ve `Seviye Merkezi` akisleri calismali.
7. Okuma ana sayfasinda masaustunde `hero + devam et` ust satiri ve iki kolonlu feed gorunmeli.
8. Okuma detayda masaustunde sol meta, orta metin ve sag sozluk/ceviri paneli birlikte calismali.
9. Gramer ana sayfasi masaustunde ust overview alani ve daha yogun grid gostermeli.
10. Profil sayfasi masaustunde bolunmus duzen ve ayarlar paneli gostermeli.
11. Browser refresh sonrasi route yenileme 404 vermemeli.
12. Chrome ve Edge uzerinde TTS butonlari hata firlatmamali.
