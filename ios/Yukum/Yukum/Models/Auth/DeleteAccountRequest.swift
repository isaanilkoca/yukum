//
//  DeleteAccountRequest.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 11.11.2026.
//

import Foundation

// Hesap silerken API'ye giden paket | Encodable [SWIFT]: Swift değerini JSON'a çevirir ({"password":"..."}) | alan adı API ile birebir aynı olmalı
// NEDEN şifre: çalınmış/açık kalmış bir oturumla hesap silinemesin diye sunucu kimliği bir kez daha doğrular
// BAĞLANTI: AccountViewModel hazırlar → AccountService.deleteAccount gönderir → POST /api/v1/account/delete

struct DeleteAccountRequest : Encodable {
    let password : String // kullancının mevcut şifresi
}
