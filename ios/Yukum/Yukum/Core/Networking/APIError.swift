//
//  APIError.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: APIError (ortak hata türü) ──────────────────────────────────
// │ FIRLATAN  : Core/Networking/APIClient (sunucu hata verdi / oturum bitti) ve Core/Networking/AuthSession (yenileme hatası)
// │ YAKALAYAN : ViewModels/* içindeki catch bloğu → Error+UserMessage.userMessage → ViewModel'in errorMessage / listError değişkeni → View kırmızı Text
// │ isSessionExpired: true ise "oturum bitti, yeniden giriş" demek (şifre yanlış gibi hatalardan ayırt etmek için)
// └──────────────────────────────────────────────────────────────────────

// KULLANIM: hata bulunca "throw APIError(message:)" fırlatılır; ekranlar (RegisterView, CarrierRegisterView, LoginView...) catch ile yakalayıp message'ı kırmızı yazar.
// nonisolated [SWIFT]: projede her şey varsayılan olarak ana iş parçacığına bağlı; bu hata türü actor'ların (AuthSession) içinden de fırlatılabilsin diye bağsız işaretlendi
// ⮕ KULLANIM [APIError]: kullanır: APIClient › perform(), AuthSession › performRefresh(), Error+UserMessage › userMessage, CarrierRegisterViewModelTests (test), ChatViewModelTests (test), CreateListingViewModelTests (test) … +7
nonisolated struct APIError: Error { // Error [SWIFT]: fırlatılabilir hata
    // ⮕ KULLANIM [message]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let message: String // ekranda göstereceğimiz yazı
    // isSessionExpired: bu hata "oturum bitti, yeniden giriş gerek" demek mi | NE İŞE YARAR: ekranlar bunu ayırt edip giriş ekranına dönebilir | varsayılan false: eski kodlar APIError(message:) yazmaya devam eder
    // ⮕ KULLANIM [isSessionExpired]: okur: AuthSessionTests (test)
    var isSessionExpired = false
}
