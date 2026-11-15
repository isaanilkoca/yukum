# E-posta Sistemi (Doğrulama Kodu + Şifremi Unuttum)

Son güncelleme: 15 Kasım 2026

## 1. Ne işe yarıyor?

İki yerde kullanıcıya 6 haneli kod gönderiyoruz:

| Durum | Ne olur |
|---|---|
| **Kayıt** | Kayıt biter bitmez e-postaya kod gider. Kod girilmeden **giriş yapılamaz**. |
| **Şifremi unuttum** | Giriş ekranındaki bağlantıdan kod istenir. Kod + yeni şifre girilince şifre değişir ve tüm cihazlardaki oturumlar kapanır. |

## 2. Akış (baştan sona)

```
iOS (kayıt / şifremi unuttum)
   │  POST /api/v1/auth/...
   ▼
API: VerificationService
   │  1) 6 haneli kod üretir
   │  2) kodun ÖZETİNİ (SHA-256) veritabanına yazar → VerificationCodes tablosu
   │  3) e-postayı "göndericiye" verir
   ▼
Gönderici (hangisi olduğu ayara bağlı, bkz. 3. bölüm)
   ├── Resend  → kullanıcının gerçek e-posta kutusu
   └── Günlük  → bilgisayardaki günlük dosyası (yalnız geliştirmede)
   ▼
Kullanıcı kodu uygulamaya yazar → API özeti karşılaştırır → doğruysa işlem yapılır
```

## 3. Kod nereye gidiyor?

| Durum | Kod nereye gider |
|---|---|
| Resend anahtarı var **ve** alıcı `isaanilk@gmail.com` | Gerçek e-posta (Gmail) |
| Resend anahtarı var ama alıcı **başka adres** | Resend reddeder (alan adı yok) → kod **günlük dosyasına** yazılır |
| Resend anahtarı yok | Kod **günlük dosyasına** yazılır |

**Neden başka adresler Gmail'e gelmiyor?** Alan adımız yok. Resend, alan adı doğrulanmadan yalnızca hesabı açan kişinin adresine gönderir. Alan adı alınınca herkese gider.

### Günlük dosyasında kodu bulmak

Dosya: `backend/src/Yukum.Api/logs/yukum-YYYYMMDD.log` (bugünün tarihi, ör. `yukum-20261115.log`)

İçinde **`GELİŞTİRME E-POSTASI`** diye ara. Kod birkaç satır altında:

```
📧 GELİŞTİRME E-POSTASI (gönderilmedi) → tema.carrier@example.com | Yüküm e-posta doğrulama kodun
...
482915
```

Terminal'den tek komutla son kod:

```
grep -A6 "GELİŞTİRME E-POSTASI" backend/src/Yukum.Api/logs/yukum-$(date +%Y%m%d).log | tail -7
```

> Bu günlük yolu yalnız **geliştirmede** açık. Canlı sunucuda açık kalırsa API hiç başlamaz (kodlar günlüğe düşmesin diye).

## 4. Resend anahtarı nerede duruyor?

- **Depoda (GitHub'da) değil.** Anahtar .NET'in **user-secrets** dosyasında, yalnız bu Mac'te:
  `~/.microsoft/usersecrets/6965967c-7fb5-4468-983e-e2ce8d4aab36/secrets.json`
- API açılırken bu dosyayı okur (yalnız geliştirme ortamında).
- Canlı sunucuda aynı ayar **ortam değişkeni** olarak verilir: `Email__ResendApiKey`.

Anahtarı değiştirmek (Terminal'de, `backend` klasöründe):

```
dotnet user-secrets set "Email:ResendApiKey" "YENI_ANAHTAR" --project src/Yukum.Api
```

Ardından API'yi yeniden başlat. Anahtarı silersen sistem otomatik olarak günlüğe yazmaya döner.

> ⚠️ Bekleyen iş: mevcut anahtar ekran görüntüsüyle sohbete düştü. Resend → **API Keys**'te silip yenisini oluştur ve yukarıdaki komutla güncelle.

## 5. Güvenlik kuralları

| Kural | Neden |
|---|---|
| Kodun kendisi saklanmaz, yalnız **özeti** | Veritabanı sızsa bile kod okunamaz |
| Kod **15 dakika** geçerli | Eski kod işe yaramaz |
| **5 yanlış** denemede kod ölür | 6 haneyi deneme-yanılmayla bulmak engellenir |
| **60 saniyede bir** yeni kod | E-posta kutusunu doldurmayı ve kotayı harcamayı engeller |
| Yeni kod eskisini geçersiz kılar | Aynı anda tek geçerli kod |
| "Kod gönder" her zaman "tamam" der | Saldırgan "bu e-posta kayıtlı mı?" diye yoklayamaz |
| Şifre değişince tüm oturumlar kapanır | Şifre çalındıysa saldırganın açık oturumu da biter |
| Doğrulanmamış hesap: önce şifre kontrol edilir | Şifre yanlışsa hesabın durumu söylenmez |

## 6. Dosyalar (nerede ne var)

**Backend**

| Dosya | Görevi |
|---|---|
| `Application/Accounts/VerificationContracts.cs` | Akış haritası + istek tipleri |
| `Application/Accounts/VerificationHandlers.cs` | Alan kontrolleri (e-posta/telefon, rol, 6 rakam, şifre kuralı) |
| `Infrastructure/Identity/VerificationService.cs` | Kod üret, sakla, doğrula, şifre değiştir |
| `Infrastructure/Identity/ResendEmailSender.cs` | Resend'e gönderir; ayarlar (`EmailOptions`) |
| `Infrastructure/Identity/LogEmailSender.cs` | Günlüğe yazan gönderici (geliştirme) |
| `Infrastructure/DependencyInjection.cs` | Hangi göndericinin kullanılacağını seçer |
| `Infrastructure/Identity/AuthService.cs` | Doğrulanmamış hesabın girişini durdurur (403) |
| `Domain/Accounts/VerificationCode.cs` | `VerificationCodes` tablosu |

**iOS**

| Dosya | Görevi |
|---|---|
| `Views/VerifyEmailView.swift` + `ViewModels/VerifyEmailViewModel.swift` | Kod ekranı (60 sn geri sayım) |
| `Views/ForgotPasswordView.swift` + `ViewModels/ForgotPasswordViewModel.swift` | Şifremi unuttum (2 adım) |
| `ViewModels/LoginViewModel.swift` | 403 "email_not_verified" gelince kod ekranını açar |
| `Models/Auth/VerificationRequests.swift` | İstek paketleri |

## 7. API uçları

| Uç | Gövde | Cevap |
|---|---|---|
| `POST /api/v1/auth/verify-email/send` | `emailOrPhone, role` | her zaman 204 |
| `POST /api/v1/auth/verify-email` | `emailOrPhone, role, code` | 204 / 400 (kod hatalı) |
| `POST /api/v1/auth/password/forgot` | `emailOrPhone, role` | her zaman 204 |
| `POST /api/v1/auth/password/reset` | `emailOrPhone, role, code, newPassword` | 204 / 400 |

`emailOrPhone`: e-posta **ya da** telefon yazılabilir; kod her zaman hesabın kayıtlı e-postasına gider.
`role`: `Shipper` veya `Carrier` (aynı e-posta iki rolde ayrı hesap olabilir).

## 8. Ayarlar

| Ayar | Nerede | Anlamı |
|---|---|---|
| `Email:ResendApiKey` | user-secrets / sunucuda ortam değişkeni | Doluysa Resend kullanılır |
| `Email:From` | varsayılan `Yüküm <onboarding@resend.dev>` | Gönderen adres |
| `Email:FallbackToLog` | `appsettings.Development.json` (true) | Resend gönderemezse günlüğe yaz (yalnız geliştirme) |
| `Auth:RequireVerifiedEmail` | varsayılan true | Doğrulanmamış hesap giriş yapamaz |

## 9. Yayına çıkarken yapılacaklar

1. Alan adı al (ör. `yukum.app`).
2. Resend → **Domains** → alan adını ekle, verdiği DNS kayıtlarını alan adı firmasına gir, doğrulanmasını bekle.
3. Sunucuda ayarla: `Email__ResendApiKey` ve `Email__From = "Yüküm <noreply@yukum.app>"`.
4. Kodda değişiklik gerekmez.

Maliyet: Resend ayda 3.000 / günde 100 e-postaya kadar ücretsiz.
