//
//  AccountViewModel.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 11.11.2026.
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: AccountViewModel ────────────────────────────────────────────
// │ EKRAN     : Views/DeleteAccountView (@State private var viewModel) | açan: Views/HomeView "Hesabı Sil" düğmesi (.sheet)
// │ SERVİS    : Models/Services/Protocols/AccountServicing → AccountService | API: POST /api/v1/account/delete
// │ OTURUM    : Models/Services/Protocols/SessionRestoring.swift → SessionSigningOut → Models/Networking/AuthSession (Keychain + bellek temizliği)
// │ AKIŞ      : View "Sil" → deleteAccount() → servis → API (anonimleştirir, oturumları iptal eder) → yerel oturum silinir → true → View giriş ekranına döner
// └──────────────────────────────────────────────────────────────────────

@Observable
final class AccountViewModel {
    private let service: AccountServicing
    private let session: SessionSigningOut // yerel oturum silmek iicn ( gercekte AuthSession.shared
    
    var password = "" // SecureField'ın yazısı | String: TextField/SecureField yazıyla çalışır
    var errorMessage: String? // sunucunun Türkçe hata mesajı (yanlış şifre, devam eden iş...) | nil: hata yok
    var isDeleting = false // istek sürerken true → düğme kilitlenir (çift silme isteği gitmesin)
    
    init(service: AccountServicing = AccountService(), session: SessionSigningOut = AuthSession.shared) {
        self.service = service
        self.session = session
    }
    
// deleteAccount: -> Bool: başarılı mı (View başarıda ekranı kapatıp giriş ekranına döner)
// ZİNCİR: DeleteAccountView "Sil" → bu fonksiyon → AccountService.deleteAccount → POST /api/v1/account/delete → sesdevsion.signOut() → true
    
    func deleteAccount() async -> Bool {
        guard !password.isEmpty else {
        errorMessage = "Hesabı silmek için şifreni gir."
            return false
        }
        isDeleting = true
        errorMessage = nil
        
        defer { isDeleting = false }  // defer [SWIFT]: fonksiyon nasıl biterse bitsin (başarı/hata) en sonda çalışır
        do {
            try await service.deleteAccount(DeleteAccountRequest(password: password))
            password = "" // şifre bekllekte kalmasın
            await session.signOut() // sunucu hesabı kapattı : Keychaindeki yenileme jetonu ve bellekteki erişim jetonu silinir
            return true
            
        } catch {
            // error.userMessage [BİZİM, Models/Networking/Error+UserMessage]: hatayı Türkçe metne çevirir (iptal ise nil → yazı gösterilmez)
            if let message = error.userMessage { errorMessage = message }
            return false
            
        }
    }
    
}

