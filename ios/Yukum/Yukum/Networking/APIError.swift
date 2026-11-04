//
//  APIError.swift
//  Yukum
//

import Foundation

// KULLANIM: hata bulunca "throw APIError(message:)" fırlatılır; ekranlar (RegisterView, CarrierRegisterView, LoginView...) catch ile yakalayıp message'ı kırmızı yazar.
// nonisolated [SWIFT]: projede her şey varsayılan olarak ana iş parçacığına bağlı; bu hata türü actor'ların (AuthSession) içinden de fırlatılabilsin diye bağsız işaretlendi
nonisolated struct APIError: Error { // Error [SWIFT]: fırlatılabilir hata
    let message: String // ekranda göstereceğimiz yazı
    // isSessionExpired: bu hata "oturum bitti, yeniden giriş gerek" demek mi | NE İŞE YARAR: ekranlar bunu ayırt edip giriş ekranına dönebilir | varsayılan false: eski kodlar APIError(message:) yazmaya devam eder
    var isSessionExpired = false
}
