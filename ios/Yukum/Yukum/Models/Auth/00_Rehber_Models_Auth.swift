//
//  00_Rehber_Models_Auth.swift — Models/Auth/ — KİMLİK VE HESAP PAKETLERİ
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Giriş, kayıt, hesap, doğrulama ve güvenlik (şikâyet/engelle) için giden/gelen JSON kalıpları. Mantık yok.
//
// DOSYA → İÇİNDEKİ TÜRLER → API UCU
//  LoginRequest.swift          LoginRequest {emailOrPhone, password, role, deviceId}          → POST /api/v1/auth/login
//  LoginResponse.swift         LoginResponse {accessToken, refreshToken, user}               ← login / refresh cevabı
//  LoginUser.swift             LoginUser {id, displayName, role} — giriş yapan kişi (HomeView'a verilir)
//  LoginRole.swift             LoginRole: shipper ("Shipper") / carrier ("Carrier") — giriş ve kayıttaki segment seçici, title Türkçe
//  RegisterRequest.swift       RegisterRequest (Yük Veren) {fullName, email, password, phone, companyName?, kvkkAccepted, termsAccepted}
//                                                                                           → POST /api/v1/auth/register/shipper
//  RegisterCarrierRequest.swift RegisterCarrierRequest (Taşımacı) {…, vehicles: nil, kvkkAccepted, termsAccepted} → POST /api/v1/auth/register/carrier
//  RegisterResponse.swift      RegisterResponse — kayıt özeti (yalnız başarı için)
//  VehicleRequest.swift        VehicleRequest — RegisterCarrierRequest.vehicles için (15 Kasım'dan beri kayıtta araç sorulmuyor → nil gider;
//                              araçlar girişten sonra Araçlarım'dan eklenir: Models/Vehicles/VehicleBody)
//  VerificationRequests.swift  CodeRequest {emailOrPhone, role}                → POST /auth/verify-email/send · /auth/password/forgot
//                              VerifyEmailRequest {+code}                       → POST /auth/verify-email
//                              ResetPasswordRequest {+code, newPassword}        → POST /auth/password/reset
//                              VerifyTarget — kod ekranının açılış bilgisi (loginAfter: doğrulanınca otomatik giriş mi)
//  AccountProfile.swift        AccountProfile (GET /account/me) · UpdateAccountProfileRequest (PUT /account/me) · AvatarResponse (POST /account/avatar)
//  DeleteAccountRequest.swift  DeleteAccountRequest {password}                  → POST /api/v1/account/delete
//  Safety.swift                ReportReason (Dolandırıcılık, Hakaret/taciz, Sahte ilan, Spam, Diğer; fn from(title:))
//                              ReportUserRequest → POST /users/{id}/report · BlockedUser ← GET /account/blocks
//                              SafetyTarget — ⋯ menüsünün hedefi (kim, hangi ilan/sohbetten)
//
// KULLANAN: Services/AuthService, AccountService, SafetyService · ViewModels/Login, Register, CarrierRegister, VerifyEmail,
//           ForgotPassword, AccountInfo, Account, Safety, BlockedUsers
// KURAL: Kayıtta iki onay AYRI (KVKK + Kullanım Koşulları); ikisi de true değilse sunucu 400 döner.
