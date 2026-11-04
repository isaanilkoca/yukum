//
//  AuthSessionTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// OTURUM TESTLERİ: erişim jetonu süresi dolunca otomatik yenileme, eşzamanlı isteklerde TEK yenileme, yenileme reddi, çıkış.
// Gerçek sunucu gerekmez: StubURLProtocol "sahte postacı" olarak istekleri yakalar ve bizim yazdığımız cevapları döner.

// Testlerin ortak yardımcıları
private func loginJSON(access: String, refresh: String) -> Data {
    Data(#"{"accessToken":"\#(access)","refreshToken":"\#(refresh)","user":{"id":"1","displayName":"Ali","role":"Shipper"}}"#.utf8)
}

private func bearer(_ request: URLRequest) -> String? { request.value(forHTTPHeaderField: "Authorization") }

// Her testin kendi oturumu, sahte postacısı ve AYRI Keychain kutusu olur (gerçek oturuma dokunulmaz)
@MainActor
private func makeEnvironment() -> (APIClient, AuthSession) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self] // bu postacı yalnız sahte protokolü kullanır
    let session = URLSession(configuration: configuration)
    let auth = AuthSession(baseURL: "http://test.local", session: session, keychainService: "yukum.tests." + UUID().uuidString)
    return (APIClient(baseURL: "http://test.local", session: session, auth: auth), auth)
}

private func response(access: String, refresh: String) -> LoginResponse {
    LoginResponse(accessToken: access, refreshToken: refresh, user: LoginUser(id: "1", displayName: "Ali", role: "Shipper"))
}

// .serialized: testler sırayla çalışır (StubURLProtocol.handler ortak bir değişken)
@MainActor
@Suite(.serialized)
struct AuthSessionTests {

    @Test func expiredAccessToken_isRefreshedOnceAndTheRequestIsRetried() async throws {
        let (api, auth) = makeEnvironment()
        await auth.signIn(response(access: "eski", refresh: "r1"))
        StubURLProtocol.reset { request in
            switch request.url!.path {
            case "/api/v1/auth/refresh": return (200, loginJSON(access: "yeni", refresh: "r2"))
            default: return bearer(request) == "Bearer yeni" ? (200, Data("[]".utf8)) : (401, Data()) // eski jeton 401, yenisi 200
            }
        }

        let result: [Listing] = try await api.send(.get, "/api/v1/listings/mine")

        #expect(result.isEmpty) // istek sonunda başarılı oldu
        #expect(StubURLProtocol.count(path: "/api/v1/auth/refresh") == 1) // yalnız BİR yenileme
        #expect(StubURLProtocol.count(path: "/api/v1/listings/mine") == 2) // ilk deneme (401) + tekrar (200)
        #expect(await auth.currentAccessToken() == "yeni")
        #expect(KeychainStore.get(key: "refreshToken", service: await auth.keychainServiceForTests) == "r2") // rotasyon: yeni yenileme jetonu saklandı
    }

    @Test func concurrentUnauthorizedRequests_shareASingleRefresh() async throws {
        let (api, auth) = makeEnvironment()
        await auth.signIn(response(access: "eski", refresh: "r1"))
        StubURLProtocol.reset { request in
            if request.url!.path == "/api/v1/auth/refresh" {
                Thread.sleep(forTimeInterval: 0.2) // yenileme yavaş: diğer istekler bunu BEKLEMEK zorunda kalsın
                return (200, loginJSON(access: "yeni", refresh: "r2"))
            }
            return bearer(request) == "Bearer yeni" ? (200, Data("[]".utf8)) : (401, Data())
        }

        // 6 istek AYNI ANDA, hepsi eski jetonla 401 alacak
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<6 { group.addTask { let r: [Listing] = try await api.send(.get, "/api/v1/listings/mine"); return r.count } }
            for try await _ in group {}
        }

        // Yenileme jetonu TEK KULLANIMLIK: 6 ayrı yenileme olsaydı sunucu 2.'yi "çalıntı" sayardı. Tek uçuş sayesinde yalnız 1 yenileme gitti.
        #expect(StubURLProtocol.count(path: "/api/v1/auth/refresh") == 1)
    }

    @Test func rejectedRefresh_clearsTheSessionAndReportsExpiry() async throws {
        let (api, auth) = makeEnvironment()
        await auth.signIn(response(access: "eski", refresh: "r1"))
        StubURLProtocol.reset { request in
            request.url!.path == "/api/v1/auth/refresh" ? (401, Data()) : (401, Data())
        }

        await #expect(throws: APIError.self) { let _: [Listing] = try await api.send(.get, "/api/v1/listings/mine") }

        #expect(await auth.hasStoredSession == false) // sunucu "geçersiz" dedi → jeton silindi, kullanıcı girişe döner
    }

    @Test func refreshNetworkFailure_keepsTheSession() async throws {
        let (api, auth) = makeEnvironment()
        await auth.signIn(response(access: "eski", refresh: "r1"))
        StubURLProtocol.reset { request in
            if request.url!.path == "/api/v1/auth/refresh" { throw URLError(.notConnectedToInternet) } // internet yok
            return (401, Data())
        }

        await #expect(throws: (any Error).self) { let _: [Listing] = try await api.send(.get, "/api/v1/listings/mine") }

        #expect(await auth.hasStoredSession == true) // ağ yokken oturum SİLİNMEZ (internet gelince devam)
    }

    @Test func loginEndpoint_doesNotTriggerRefreshOn401() async throws {
        let (api, _) = makeEnvironment()
        StubURLProtocol.reset { _ in (401, Data(#"{"detail":"E-posta veya şifre hatalı."}"#.utf8)) }

        do {
            let _: LoginResponse = try await api.send(.post, "/api/v1/auth/login", body: ["x": "y"], authorized: false)
            Issue.record("hata fırlatılmalıydı")
        } catch let error as APIError {
            #expect(error.message == "E-posta veya şifre hatalı.") // sunucunun Türkçe mesajı gösterilir
            #expect(error.isSessionExpired == false) // "şifre yanlış" ≠ "oturum bitti"
        }

        #expect(StubURLProtocol.count(path: "/api/v1/auth/refresh") == 0) // giriş ucunda 401 yenileme TETİKLEMEZ
    }

    @Test func signOut_clearsTheSessionAndNotifiesTheServer() async throws {
        let (_, auth) = makeEnvironment()
        await auth.signIn(response(access: "a", refresh: "r1"))
        StubURLProtocol.reset { _ in (204, Data()) }

        await auth.signOut()

        #expect(await auth.hasStoredSession == false)
        #expect(await auth.currentAccessToken() == nil)
        #expect(StubURLProtocol.count(path: "/api/v1/auth/logout") == 1) // sunucuya da haber verildi (jeton orada iptal edilir)
    }

    @Test func restore_withoutAStoredSession_returnsNil_andWithOneRefreshesTheUser() async throws {
        let (_, auth) = makeEnvironment()
        StubURLProtocol.reset { _ in (200, loginJSON(access: "yeni", refresh: "r2")) }
        #expect(try await auth.restore() == nil) // jeton yok → giriş ekranı, sunucuya gidilmez
        #expect(StubURLProtocol.count(path: "/api/v1/auth/refresh") == 0)

        await auth.signIn(response(access: "a", refresh: "r1"))
        let user = try await auth.restore() // otomatik giriş
        #expect(user?.displayName == "Ali")
        #expect(await auth.currentAccessToken() == "yeni")
    }
}
