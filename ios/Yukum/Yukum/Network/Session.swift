//
//  Session.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 30.10.2026.
//

import Foundation


// BU DOSYA NE İŞE YARAR? Girişte gelen jetonu (ben girişliyim notu) uygulama açık kaldığı sürece tutar.
// Tek bir yerde durur, her ekran ve servis buradan okur. Uygulama kapanınca silinir (Keychain sonra).
// BAĞLANTI: View/LoginView.swift giriş başarılı olunca yazar | sonraki servisler (ilan gönderme, ilanlarım) okuyup "Authorization: Bearer" başlığına koyar

enum Session { // enum [SWIFT]: örnek üretilmeyen, sadece ortak değişken tutan kutu | adı [BİZİM]
    
    
    static var accessToken: String? // static: Session.accessToken diye her yerden erişilir | String?: nil = giriş yapılmadı
}
