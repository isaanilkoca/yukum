//
//  HTTPMethod.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: HTTPMethod ──────────────────────────────────────────────────
// │ NE        : İsteğin türü: .get (veri iste), .post (işlem/yeni kayıt), .put, .delete
// │ KULLANAN  : Services/*Service.swift → api.send(.get, ...) | Models/Networking/APIClient → request.httpMethod = method.rawValue
// └──────────────────────────────────────────────────────────────────────

// HTTP yöntemleri | enum [SWIFT]: sabit seçenek listesi | rawValue: sunucuya giden yazı
// ⮕ KULLANIM [HTTPMethod]: kullanır: APIClient › send(), APIClient › sendNoContent(), APIClient › perform(), APIClient › execute()
enum HTTPMethod: String {
    // ⮕ KULLANIM [get]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    case get = "GET"       // veri iste
    // ⮕ KULLANIM [post]: okur: AuthService › register(), AuthService › registerCarrier(), AuthService › login(), ChatService › send(), ChatService › complete(), ListingService › create() … +5
    case post = "POST"     // veri gönder / işlem yap
    // ⮕ KULLANIM [put]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    case put = "PUT"       // kaydı güncelle
    // ⮕ KULLANIM [delete]: okur: ChatService › clear(), OfferService › hide()
    case delete = "DELETE" // sil
}
