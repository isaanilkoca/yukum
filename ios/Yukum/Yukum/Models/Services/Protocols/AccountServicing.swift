//
//  AccountServicing.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 11.11.2026.
//

import Foundation

// Hesap işlemlerinin SÖZLEŞMESİ | protocol [SWIFT]: gövdesiz fonksiyon listesi, "bu fonksiyonlara sahip olan her tür bu sözleşmeyi karşılar"
// NEDEN protocol: ViewModel gerçek servise değil bu sözleşmeye bağlanır → testte sunucusuz SAHTE servis (YukumTests/Support/FakeAccountService) verilir
// GERÇEK: Models/Services/AccountService.swift | KULLANAN: ViewModels/AccountViewModel

protocol AccountServicing {
    
    // deleteAccount: hesabı siler (sunucu anonimleştirir) | async throws [SWIFT]: beklemeli iş + hata fırlatabilir
    // ÇAĞIRAN: AccountViewModel.deleteAccount() | API: POST /api/v1/account/delete | başarıda cevap gövdesi yok (204)
    
    func deleteAccount(_ body: DeleteAccountRequest) async throws

    // ─── Hesap Bilgilerim (15 Kasım) | KULLANAN: ViewModels/AccountInfoViewModel | sahtesi: YukumTests/Support/FakeAccountService ───
    func profile() async throws -> AccountProfile                                   // GET  /api/v1/account/me
    func update(_ body: UpdateAccountProfileRequest) async throws -> AccountProfile // PUT  /api/v1/account/me → güncel hâli döner
    func uploadAvatar(jpeg: Data) async throws -> String                            // POST /api/v1/account/avatar → yeni avatarUrl
    func deleteAvatar() async throws                                                // DELETE /api/v1/account/avatar
}
