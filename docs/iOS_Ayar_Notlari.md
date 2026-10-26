# iOS ayar notları (Xcode'da ve proje dosyalarında yapılan değişiklikler)

Kural: Xcode ayarı ya da proje dosyası değiştirildiğinde buraya yazılır.

## 26 Ekim 2026

| Ne | Nerede | Neden |
|---|---|---|
| Xcode projesi `ios/Yukum` içinde açıldı | `ios/Yukum/Yukum.xcodeproj` | iOS kodu backend ile aynı repoda durur. |
| Minimum iOS **26.5 → 18.0** | `project.pbxproj` → `IPHONEOS_DEPLOYMENT_TARGET`. Xcode: Target → General → Minimum Deployments | Xcode varsayılanı 26.5 idi; eski simülatör/cihazda uygulama kurulmuyordu. |
| Yerel `http` izni (**NSAllowsLocalNetworking = true**) | `ios/Yukum/Yukum/Info.plist` (Xcode: Target → Info → App Transport Security Settings) | iOS varsayılan olarak yalnız `https` ister; yerel API `http://localhost:5054`. **Canlıya çıkınca kaldırılır, API `https` olur.** |
| API adresi `http://localhost:5054` | `Network/AuthService.swift` → `baseURL` | Simülatörde `localhost` = Mac. Gerçek telefonda çalışmaz; Mac'in IP adresi gerekir. |
| Kayıtta il sabit **34 (İstanbul)** | `View/RegisterView.swift` → `cityId: 34` | API il zorunlu istiyor, il seçimi anasayfada olacak. **Geçici**; il seçimi yapılınca değişecek. |

## Dosya haritası (şu an)
- `View/LoginView.swift`: giriş ekranı (tasarım hazır, düğmeler henüz boş)
- `View/RegisterView.swift`: kayıt ekranı (API'ye bağlı, çalışıyor)
- `Network/RegisterRequest.swift`: gönderilen/gelen paketler (RegisterRequest, RegisterResponse, APIErrorResponse)
- `Network/AuthService.swift`: API çağrıları (şimdilik yalnız `register`)

## Çalıştırma hatırlatması
1. Docker Desktop aç, `docker start yukum-sql`
2. `dotnet run --project backend/src/Yukum.Api --launch-profile http`
3. Xcode'da simülatör (iPhone 17, iOS 26.5) seç, ▶

## Doğrulananlar
- 26 Ekim 2026: simülatörden kayıt oldu, `Users` tablosuna düştü (şehir 34).
