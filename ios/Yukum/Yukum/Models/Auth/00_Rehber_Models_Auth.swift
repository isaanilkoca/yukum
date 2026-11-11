//
//  00_Rehber_Models_Auth.swift — Models/Auth — giriş ve kayıt paketleri
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Kod yok, sadece alanlar. 'Request' = API'ye GİDEN paket, 'Response' = API'den GELEN cevap.
// 
//
//  LoginRole               seçenek: giriş ekranındaki hesap türü (Yük Veren / Taşımacı). Aynı e-posta iki rolde kayıtlı olabilir (K-022); LoginView Picker, LoginViewModel.role
//  LoginRequest            giden: e-posta/telefon, şifre, role, deviceId. LoginViewModel hazırlar → AuthService.login gönderir
//  LoginResponse           gelen: jetonlar + LoginUser. AuthService jetonları AuthSession'a verir, LoginViewModel user'ı alır
//  LoginUser               giriş yapan kişi (ad, rol). HomeView'ın başlığı ve rol kararı bundan gelir
//  RegisterRequest         giden: Yük Veren kaydı. RegisterViewModel → AuthService.register
//  RegisterCarrierRequest  giden: Taşımacı kaydı (+ araç listesi). CarrierRegisterViewModel → AuthService.registerCarrier
//  VehicleRequest          RegisterCarrierRequest içindeki araç (tür, kapasite, plaka)
//  RegisterResponse        gelen: kayıt cevabı. RegisterViewModel / CarrierRegisterViewModel başarı kararını verir
