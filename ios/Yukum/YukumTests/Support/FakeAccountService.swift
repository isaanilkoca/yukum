//
//  FakeAccountService.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// AccountServicing'in sahtesi: sunucu yok, cevabı test belirler, giden istekler kaydedilir
final class FakeAccountService: AccountServicing {
    var deleteResult: Result<Void, Error> = .success(())
    private(set) var deleteCalls: [DeleteAccountRequest] = []
    func deleteAccount(_ body: DeleteAccountRequest) async throws { deleteCalls.append(body); try deleteResult.get() }
}
