//
//  ErrorMessages.swift
//  Yukum
//

import Foundation

// BU DOSYA: "bu hata kullanıcıya ne diye gösterilsin?" kuralı TEK YERDE. Eskiden her ekranda aynı üç satırlık catch bloğu vardı:
//   catch AuthError → mesajını göster | catch iptal → sessiz geç | catch başka → "Sunucuya ulaşılamadı."
// BAĞLANTI: tüm ViewModel'ler catch içinde "error.userMessage" kullanır
extension Error {

    // userMessage: ekranda gösterilecek yazı | nil: GÖSTERME (iş iptal edilmiş, hata değil)
    // İPTAL ≠ HATA: SwiftUI ekran yenilenirken/çıkılırken çalışan işi (.task) iptal eder; iptal edilen internet isteği "cancelled" hatası fırlatır.
    // Bunu kullanıcıya "Sunucuya ulaşılamadı." diye göstermek yanlış olur (daha önce ekranda yanlış hata yazısı kalmasının sebebi buydu).
    var userMessage: String? {
        if let error = self as? AuthError { return error.message } // sunucunun ya da APIClient'ın hazırladığı Türkçe mesaj
        if self is CancellationError || (self as? URLError)?.code == .cancelled { return nil } // iptal: sessiz geç
        return "Sunucuya ulaşılamadı." // internet yok, sunucu kapalı, cevap okunamadı
    }
}
