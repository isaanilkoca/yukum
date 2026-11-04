//
//  HTTPMethod.swift
//  Yukum
//

import Foundation

// HTTP yöntemleri | enum [SWIFT]: sabit seçenek listesi | rawValue: sunucuya giden yazı
enum HTTPMethod: String {
    case get = "GET"       // veri iste
    case post = "POST"     // veri gönder / işlem yap
    case put = "PUT"       // kaydı güncelle
    case delete = "DELETE" // sil
}
