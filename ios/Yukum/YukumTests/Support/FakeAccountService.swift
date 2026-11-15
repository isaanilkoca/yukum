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

    var profileResult: Result<AccountProfile, Error> = .success(FakeAccountService.sampleProfile)
    var updateResult: Result<AccountProfile, Error>? = nil // nil → gönderilen değerlerle güncellenmiş örnek döner
    var uploadResult: Result<String, Error> = .success("/api/v1/avatars/yeni")
    private(set) var updateCalls: [UpdateAccountProfileRequest] = []
    private(set) var uploadCalls: [Data] = []
    private(set) var deleteAvatarCalls = 0

    func profile() async throws -> AccountProfile { try profileResult.get() }
    func update(_ body: UpdateAccountProfileRequest) async throws -> AccountProfile {
        updateCalls.append(body)
        if let updateResult { return try updateResult.get() }
        let p = try profileResult.get()
        return AccountProfile(id: p.id, role: p.role, fullName: body.fullName, email: p.email, phone: "+90" + body.phone, avatarUrl: p.avatarUrl,
                              cityId: body.cityId, about: body.about, companyName: body.companyName, taxNumber: body.taxNumber, taxOffice: body.taxOffice,
                              averageRating: p.averageRating, ratingCount: p.ratingCount, completedJobCount: p.completedJobCount)
    }
    func uploadAvatar(jpeg: Data) async throws -> String { uploadCalls.append(jpeg); return try uploadResult.get() }
    func deleteAvatar() async throws { deleteAvatarCalls += 1 }
}

// ─── Hesap Bilgilerim (15 Kasım) ───
extension FakeAccountService {
    static let sampleProfile = AccountProfile(id: "u1", role: "Shipper", fullName: "Ali Veli", email: "ali@x.com", phone: "+905321234567",
                                              avatarUrl: nil, cityId: 33, about: nil, companyName: nil, taxNumber: nil, taxOffice: nil,
                                              averageRating: nil, ratingCount: nil, completedJobCount: nil)
}
