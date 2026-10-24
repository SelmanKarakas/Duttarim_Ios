# Duttarim iOS test sürümü

Bu kaynak paket, Android projesindeki güncel ortak arayüzü ve içerikleri iOS projesine taşır. iOS'a özgü mikrofon, akort, titreşim, görünüm ve ekran yönü köprüleri `ios/App/App` içindedir. iOS uygulama sürümü `1.1` olarak ayarlanmıştır. Paket imzalı IPA içermez.

## GitHub'a yükleme

Kaynaklar `SelmanKarakas/Duttarim_Ios` deposunun `main` dalındadır. `node_modules` ve `ios/App/App/public` depoya yüklenmez; derleme sırasında üretilir. Android'e özgü `android` klasörü bu iOS deposuna alınmadı.

## Windows'tan TestFlight'a gönderme

1. GitHub'daki `SelmanKarakas/Duttarim_Ios` deposunun `main` dalındaki güncel kodu kullanın.
2. Codemagic'te bu depoyu açın; `codemagic.yaml` içindeki **Duttarim iOS TestFlight** iş akışını seçin.
3. Codemagic'teki `Duttarim-Codemagic` App Store Connect bağlantısı ve `com.duttarim.app` için App Store dağıtım imzalama profili etkin olmalı. Var olan yapılandırma bunları kullanır.
4. `main` dalından bir derleme başlatın. Codemagic, `npm ci`, veri doğrulaması, `npx cap sync ios`, imzalama ve IPA derlemesini Mac üzerinde yapar. Derleme numarası Codemagic'in `$BUILD_NUMBER` değeriyle atanır.
5. İş akışı IPA'yı App Store Connect'e yükler. `submit_to_testflight: false` olduğundan otomatik beta grubuna göndermez. App Store Connect > uygulama > TestFlight bölümünde işlenen derlemeyi seçin ve iç test grubuna ekleyin. Gerekirse beta uygulama incelemesi için istenen bilgileri tamamlayın.
6. Test kullanıcıları TestFlight davetiyle yükler. Yayın için aynı sürümün onaylanan derlemesini ayrıca App Store sürümüne seçin; bu iş akışı mağazaya otomatik yayın yapmaz.

## Kontrol edilenler

- `npm test` geçti.
- `npm run test:versions` geçti.
- `npx cap sync ios` Windows'ta geçti.
- Swift/Xcode derlemesi ve gerçek iPhone'da akort ölçümü henüz doğrulanmadı; ilk Codemagic derlemesi bunları sınar.
