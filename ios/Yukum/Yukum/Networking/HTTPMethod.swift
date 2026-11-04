//
//  HTTPMethod.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: HTTPMethod ──────────────────────────────────────────────────
// │ NE        : İsteğin türü: .get (veri iste), .post (işlem/yeni kayıt), .put, .delete
// │ KULLANAN  : Services/*Service.swift → api.send(.get, ...) | Networking/APIClient → request.httpMethod = method.rawValue
// │ HAZIR (Swift/Apple) [SWIFT] : enum, String
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: HTTPMethod | değişken/durumlar: get, post, put, delete
// └──────────────────────────────────────────────────────────────────────

// HTTP yöntemleri | enum [SWIFT]: sabit seçenek listesi | rawValue: sunucuya giden yazı
enum HTTPMethod: String {
    case get = "GET"       // veri iste
    case post = "POST"     // veri gönder / işlem yap
    case put = "PUT"       // kaydı güncelle
    case delete = "DELETE" // sil
}
