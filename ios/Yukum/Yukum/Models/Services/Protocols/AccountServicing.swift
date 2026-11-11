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
    
}
