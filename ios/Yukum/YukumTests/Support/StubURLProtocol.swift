//
//  StubURLProtocol.swift
//  YukumTests
//

import Foundation
@testable import Yukum

// StubURLProtocol: URLProtocol [SWIFT] = ağ isteklerini araya girip karşılayan hazır mekanizma | testlerde sunucu yerine geçer
// nonisolated: ağ katmanı arka plan iş parçacıklarında çağırır, ana iş parçacığına bağlı olmamalı
nonisolated final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    // handler: gelen isteğe verilecek cevap (durum kodu + gövde) | hata fırlatırsa ağ hatası gibi davranır
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    private static let lock = NSLock() // istek kaydına birden çok iş parçacığı yazar: kilitle
    nonisolated(unsafe) private static var log: [URLRequest] = []
    static var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return log }
    static func reset(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, Data)) {
        lock.lock(); log = []; lock.unlock()
        self.handler = handler
    }
    static func count(path: String) -> Int { requests.filter { $0.url?.path == path }.count } // bu adrese kaç istek gitti

    override class func canInit(with request: URLRequest) -> Bool { true } // her isteği biz karşılarız
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.log.append(request); Self.lock.unlock()
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
