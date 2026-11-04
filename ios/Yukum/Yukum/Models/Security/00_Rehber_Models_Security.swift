//
//  00_Rehber_Models_Security.swift — Models/Security — güvenli saklama
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// API'ye gitmez; telefonun güvenli deposuyla (Keychain) konuşur.
// 
//
//  KeychainStore  Keychain'e yaz/oku/sil. Yenileme jetonu burada saklanır  ← AuthSession, DeviceID
//  DeviceID       bu telefona sabit kimlik (ilk kullanımda üretilir, Keychain'de durur). Giriş isteğine eklenir  ← LoginViewModel, AuthSession
