//
//  ServiceContractTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// SÖZLEŞME TESTLERİ (15 Kasım): her servis fonksiyonu sunucuya DOĞRU yöntem + adres + sorgu + gövde ile mi gidiyor?
// NEDEN: ViewModel testleri sahte servis kullanır; servis → API köprüsündeki bir yazım hatası ("/offer" yerine "/offers") orada yakalanmaz.
// NASIL: ContractStub (bu dosyada) istekleri yakalar (gerçek ağ yok). Cevap çözümü burada önemsiz (try?): yalnız giden istek sınanır.
// Adres listesinin kaynağı: backend Controllers (AuthController, ListingsController, OffersController…)

// KENDİ sahte ağı: StubURLProtocol'ün durumu (handler, istek kaydı) static ve ortak; AuthSessionTests ile AYNI ANDA çalışınca
//   birbirinin isteğini görüyordu (iki suite ayrı ayrı .serialized ama birbirine göre paralel) → bu dosyanın ayrı sınıfı var.
nonisolated final class ContractStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    private static let lock = NSLock()
    nonisolated(unsafe) private static var log: [URLRequest] = []
    static var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return log }
    static func reset(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, Data)) { lock.lock(); log = []; lock.unlock(); self.handler = handler }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.log.append(request); Self.lock.unlock()
        do {
            let (status, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

// Sahte ağ + giriş yapılmış oturum (yetkili uçlar Bearer jeton taşısın) | her test kendi Keychain kutusunu kullanır
@MainActor
private func makeAPI() async -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ContractStub.self]
    let session = URLSession(configuration: configuration)
    let auth = AuthSession(baseURL: "http://test.local", session: session, keychainService: "yukum.contract." + UUID().uuidString)
    await auth.signIn(LoginResponse(accessToken: "jeton", refreshToken: "yenile", user: LoginUser(id: "1", displayName: "Ali", role: "Shipper")))
    return APIClient(baseURL: "http://test.local", session: session, auth: auth)
}

// Son isteğin özeti: "YÖNTEM /yol" + sorgu + JSON gövde
private struct Sent {
    let method: String, path: String, query: [String: String], body: [String: Any]?, bearer: String?
    var line: String { "\(method) \(path)" }
}

private func last() throws -> Sent {
    let request = try #require(ContractStub.requests.last)
    let url = try #require(request.url)
    let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    // URLProtocol'de gövde httpBody yerine akışta (httpBodyStream) gelir
    var data = request.httpBody
    if data == nil, let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 64 * 1024), collected = Data()
        while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; collected.append(buffer, count: n) }
        data = collected
    }
    let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    return Sent(method: request.httpMethod ?? "", path: url.path,
                query: Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a }),
                body: json, bearer: request.value(forHTTPHeaderField: "Authorization"))
}

@MainActor
@Suite(.serialized) // ContractStub bu suite içinde ortak: testler sırayla
struct ServiceContractTests {

    init() { ContractStub.reset { _ in (204, Data()) } } // her uca boş başarı; içerik bu testlerde önemsiz

    // MARK: Kimlik (jetonsuz uçlar)

    @Test func auth_registerAndVerificationEndpoints_goWithoutAToken() async throws {
        let s = AuthService(api: await makeAPI())
        _ = try? await s.register(RegisterRequest(fullName: "A", email: "a@x.com", password: "Abcdefg1", phone: "05321234567", companyName: nil, kvkkAccepted: true, termsAccepted: true))
        var r = try last(); #expect(r.line == "POST /api/v1/auth/register/shipper"); #expect(r.bearer == nil); #expect(r.body?["termsAccepted"] as? Bool == true)

        _ = try? await s.registerCarrier(RegisterCarrierRequest(fullName: "B", email: "b@x.com", password: "Abcdefg1", phone: "05321234568", vehicles: nil, kvkkAccepted: true, termsAccepted: true))
        r = try last(); #expect(r.line == "POST /api/v1/auth/register/carrier"); #expect(r.body?["vehicles"] == nil) // nil alan JSON'a yazılmaz

        try await s.sendVerificationCode(CodeRequest(emailOrPhone: "a@x.com", role: "Shipper"))
        r = try last(); #expect(r.line == "POST /api/v1/auth/verify-email/send"); #expect(r.bearer == nil)
        try await s.verifyEmail(VerifyEmailRequest(emailOrPhone: "a@x.com", role: "Shipper", code: "123456"))
        r = try last(); #expect(r.line == "POST /api/v1/auth/verify-email"); #expect(r.body?["code"] as? String == "123456")
        try await s.forgotPassword(CodeRequest(emailOrPhone: "a@x.com", role: "Carrier"))
        r = try last(); #expect(r.line == "POST /api/v1/auth/password/forgot"); #expect(r.body?["role"] as? String == "Carrier")
        try await s.resetPassword(ResetPasswordRequest(emailOrPhone: "a@x.com", role: "Shipper", code: "123456", newPassword: "YeniSifre9"))
        r = try last(); #expect(r.line == "POST /api/v1/auth/password/reset"); #expect(r.body?["newPassword"] as? String == "YeniSifre9")
    }

    @Test func cities_areAnonymous() async throws {
        let s = CityService(api: await makeAPI())
        _ = try? await s.cities()
        #expect(try last().line == "GET /api/v1/cities"); #expect(try last().bearer == nil)
        _ = try? await s.districts(cityId: 33)
        #expect(try last().line == "GET /api/v1/cities/33/districts")
    }

    // MARK: Hesap

    @Test func account_endpoints_carryTheToken() async throws {
        let s = AccountService(api: await makeAPI())
        _ = try? await s.profile()
        var r = try last(); #expect(r.line == "GET /api/v1/account/me"); #expect(r.bearer == "Bearer jeton")
        _ = try? await s.update(UpdateAccountProfileRequest(fullName: "Ali", phone: "5321234567", currentPassword: nil, cityId: 33, about: nil, companyName: nil, taxNumber: nil, taxOffice: nil))
        r = try last(); #expect(r.line == "PUT /api/v1/account/me"); #expect(r.body?["cityId"] as? Int == 33)
        try await s.deleteAvatar()
        #expect(try last().line == "DELETE /api/v1/account/avatar")
        _ = try? await s.uploadAvatar(jpeg: Data([0xFF, 0xD8, 0xFF]))
        r = try last(); #expect(r.line == "POST /api/v1/account/avatar")
        #expect(ContractStub.requests.last?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data") == true)
        try await s.deleteAccount(DeleteAccountRequest(password: "Abcdefg1"))
        r = try last(); #expect(r.line == "POST /api/v1/account/delete"); #expect(r.body?["password"] as? String == "Abcdefg1")
    }

    // MARK: İlan

    @Test func listings_crudFavoritesStatsAndReference() async throws {
        let s = ListingService(api: await makeAPI())
        let body = CreateListingRequest(title: "Gübre", description: nil, weightKg: 1000, vehicleType: "Truck", fromCityId: 33, fromDistrictId: 1, toCityId: 6, toDistrictId: 2, pickupDate: "2026-12-01", budget: 5000)
        _ = try? await s.create(body)
        var r = try last(); #expect(r.line == "POST /api/v1/listings"); #expect(r.body?["title"] as? String == "Gübre")
        _ = try? await s.update(listingId: "L1", body)
        #expect(try last().line == "PUT /api/v1/listings/L1")
        _ = try? await s.myListings()
        r = try last(); #expect(r.line == "GET /api/v1/listings/mine"); #expect(r.query["all"] == nil)
        _ = try? await s.allMyListings()
        r = try last(); #expect(r.line == "GET /api/v1/listings/mine"); #expect(r.query["all"] == "true")
        try await s.setFavorite(listingId: "L1", isFavorite: true)
        #expect(try last().line == "PUT /api/v1/listings/L1/favorite")
        try await s.setFavorite(listingId: "L1", isFavorite: false)
        #expect(try last().line == "DELETE /api/v1/listings/L1/favorite")
        _ = try? await s.favorites()
        #expect(try last().line == "GET /api/v1/listings/favorites")
        try await s.recordView(listingId: "L1")
        #expect(try last().line == "POST /api/v1/listings/L1/view")
        _ = try? await s.stats(listingId: "L1")
        #expect(try last().line == "GET /api/v1/listings/L1/stats")
        _ = try? await s.priceReference(fromCityId: 33, toCityId: 6, vehicleType: "Truck")
        r = try last(); #expect(r.line == "GET /api/v1/price-reference")
        #expect(r.query["fromCityId"] == "33" && r.query["toCityId"] == "6" && r.query["vehicleType"] == "Truck")
        try await s.cancel(listingId: "L1")
        #expect(try last().line == "POST /api/v1/listings/L1/cancel")
    }

    @Test func openListings_sendsTheFilterAsQuery_andLocationOnlyWhenGiven() async throws {
        let s = ListingService(api: await makeAPI())
        var filter = OpenListingsFilter()
        filter.fromCityId = 33; filter.maxBudget = 9000; filter.vehicleType = "Truck"; filter.maxDistanceKm = 50; filter.minWeightKg = 500
        _ = try? await s.openListings(filter: filter, page: 2, lat: 36.8, lon: 34.6)
        var r = try last()
        #expect(r.line == "GET /api/v1/listings")
        #expect(r.query["page"] == "2" && r.query["fromCityId"] == "33" && r.query["maxBudget"] == "9000")
        #expect(r.query["vehicleType"] == "Truck" && r.query["maxDistanceKm"] == "50" && r.query["minWeightKg"] == "500")
        #expect(r.query["lat"] != nil && r.query["lon"] != nil)

        _ = try? await s.openListings(filter: OpenListingsFilter(), page: 1)
        r = try last()
        #expect(r.query["lat"] == nil && r.query["fromCityId"] == nil) // boş filtre: yalnız sayfa bilgisi
    }

    // MARK: Teklif ve sohbet

    @Test func offers_lifecycleEndpoints() async throws {
        let s = OfferService(api: await makeAPI())
        _ = try? await s.create(listingId: "L1", CreateOfferRequest(amount: 4500, note: "hızlı", vehicleId: "V1", estimatedDeliveryDate: "2026-12-05"))
        var r = try last(); #expect(r.line == "POST /api/v1/listings/L1/offers")
        #expect(r.body?["amount"] as? Int == 4500 && r.body?["vehicleId"] as? String == "V1" && r.body?["estimatedDeliveryDate"] as? String == "2026-12-05")
        _ = try? await s.listingOffers(listingId: "L1"); #expect(try last().line == "GET /api/v1/listings/L1/offers")
        try await s.decide(offerId: "O1", accept: true); #expect(try last().line == "POST /api/v1/offers/O1/accept")
        try await s.decide(offerId: "O1", accept: false); #expect(try last().line == "POST /api/v1/offers/O1/reject")
        _ = try? await s.myOffers(); #expect(try last().line == "GET /api/v1/offers/mine")
        _ = try? await s.unseenCount(); #expect(try last().line == "GET /api/v1/offers/mine/unseen-count")
        try await s.markSeen(); #expect(try last().line == "POST /api/v1/offers/mine/seen")
        try await s.hide(offerId: "O1"); #expect(try last().line == "DELETE /api/v1/offers/O1")
        try await s.withdraw(offerId: "O1"); #expect(try last().line == "POST /api/v1/offers/O1/withdraw")
        try await s.advance(offerId: "O1"); #expect(try last().line == "POST /api/v1/offers/O1/advance")
        _ = try? await s.shipperHistory(); #expect(try last().line == "GET /api/v1/offers/history")
        try await s.requestCancel(offerId: "O1", reason: "Araç arızası", note: nil, reopenListing: true)
        r = try last(); #expect(r.line == "POST /api/v1/offers/O1/cancel-request"); #expect(r.body?["reason"] as? String == "Araç arızası")
        try await s.approveCancel(offerId: "O1", reopenListing: false)
        r = try last(); #expect(r.line == "POST /api/v1/offers/O1/cancel-request/approve"); #expect(r.body?["reopenListing"] as? Bool == false)
        try await s.rejectCancel(offerId: "O1"); #expect(try last().line == "POST /api/v1/offers/O1/cancel-request/reject")
        try await s.withdrawCancel(offerId: "O1"); #expect(try last().line == "DELETE /api/v1/offers/O1/cancel-request")
    }

    @Test func chat_andReviews() async throws {
        let api = await makeAPI()
        let chat = ChatService(api: api)
        _ = try? await chat.messages(offerId: "O1"); #expect(try last().line == "GET /api/v1/offers/O1/messages")
        try await chat.send(offerId: "O1", SendMessageRequest(text: "Merhaba"))
        var r = try last(); #expect(r.line == "POST /api/v1/offers/O1/messages"); #expect(r.body?["text"] as? String == "Merhaba")
        try await chat.clear(offerId: "O1"); #expect(try last().line == "DELETE /api/v1/offers/O1/messages")
        try await chat.complete(offerId: "O1"); #expect(try last().line == "POST /api/v1/offers/O1/complete")

        let reviews = ReviewService(api: api)
        try await reviews.create(offerId: "O1", CreateReviewRequest(rating: 5, comment: "Zamanında"))
        r = try last(); #expect(r.line == "POST /api/v1/offers/O1/review"); #expect(r.body?["rating"] as? Int == 5)
        _ = try? await reviews.carrierProfile(id: "C1"); #expect(try last().line == "GET /api/v1/carriers/C1")
        _ = try? await reviews.shipperProfile(id: "S1"); #expect(try last().line == "GET /api/v1/shippers/S1")
    }

    // MARK: Bildirim, araç, güvenlik

    @Test func notifications_includingTheDeviceTokenQuery() async throws {
        let s = NotificationService(api: await makeAPI())
        _ = try? await s.list(page: 3)
        var r = try last(); #expect(r.line == "GET /api/v1/notifications"); #expect(r.query["page"] == "3")
        _ = try? await s.unreadCount(); #expect(try last().line == "GET /api/v1/notifications/unread-count")
        try await s.markRead(id: "N1"); #expect(try last().line == "POST /api/v1/notifications/N1/read")
        try await s.markAllRead(); #expect(try last().line == "POST /api/v1/notifications/read-all")
        try await s.delete(id: "N1"); #expect(try last().line == "DELETE /api/v1/notifications/N1")
        try await s.registerDevice(RegisterDeviceRequest(token: "apns", deviceId: "D1", sandbox: true))
        r = try last(); #expect(r.line == "PUT /api/v1/notifications/device-token"); #expect(r.body?["sandbox"] as? Bool == true)
        try await s.removeDevice(deviceId: "D1")
        r = try last()
        #expect(r.line == "DELETE /api/v1/notifications/device-token") // "?" adrese karışmadı, sorgu olarak gitti
        #expect(r.query["deviceId"] == "D1")
    }

    @Test func vehicles_andSafety() async throws {
        let api = await makeAPI()
        let vehicles = VehicleService(api: api)
        let body = VehicleBody(type: "Truck", plateNumber: "33 ABC 123", capacityKg: nil, brand: "Volvo", model: "FH", year: 2020)
        _ = try? await vehicles.mine(); #expect(try last().line == "GET /api/v1/vehicles")
        _ = try? await vehicles.add(body)
        var r = try last(); #expect(r.line == "POST /api/v1/vehicles"); #expect(r.body?["plateNumber"] as? String == "33 ABC 123")
        _ = try? await vehicles.update(id: "V1", body); #expect(try last().line == "PUT /api/v1/vehicles/V1")
        try await vehicles.delete(id: "V1"); #expect(try last().line == "DELETE /api/v1/vehicles/V1")

        let safety = SafetyService(api: api)
        try await safety.block(userId: "U2"); #expect(try last().line == "PUT /api/v1/users/U2/block")
        try await safety.unblock(userId: "U2"); #expect(try last().line == "DELETE /api/v1/users/U2/block")
        _ = try? await safety.blocked(); #expect(try last().line == "GET /api/v1/account/blocks")
        try await safety.report(userId: "U2", ReportUserRequest(reason: "Fraud", note: nil, listingId: "L1", offerId: nil))
        r = try last(); #expect(r.line == "POST /api/v1/users/U2/report")
        #expect(r.body?["reason"] as? String == "Fraud" && r.body?["listingId"] as? String == "L1")
    }

    // MARK: Hata çevirisi (bütün servisler aynı yoldan)

    @Test func serverErrors_reachTheScreenInTurkish_withTheMachineCode() async throws {
        ContractStub.reset { _ in
            (403, Data(#"{"title":"E-posta doğrulanmadı","status":403,"detail":"E-posta adresin henüz doğrulanmadı.","code":"email_not_verified"}"#.utf8))
        }
        let s = AuthService(api: await makeAPI())
        do {
            try await s.verifyEmail(VerifyEmailRequest(emailOrPhone: "a@x.com", role: "Shipper", code: "000000"))
            Issue.record("Hata bekleniyordu")
        } catch let error as APIError {
            #expect(error.message == "E-posta adresin henüz doğrulanmadı.")
            #expect(error.code == "email_not_verified")
        }

        ContractStub.reset { _ in (400, Data(#"{"status":400,"errors":{"code":["Kod 6 rakamdan oluşmalı."]}}"#.utf8)) }
        do {
            try await s.verifyEmail(VerifyEmailRequest(emailOrPhone: "a@x.com", role: "Shipper", code: "1"))
            Issue.record("Hata bekleniyordu")
        } catch let error as APIError {
            #expect(error.message == "Kod 6 rakamdan oluşmalı.") // alan hatası genel mesajdan önce gelir
            #expect(error.code == nil)
        }
    }
}
