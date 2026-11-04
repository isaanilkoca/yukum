//
//  SessionRestoring.swift
//  Yukum
//

import Foundation

// SessionRestoring: "kayıtlı oturum varsa kullanıcıyı geri getir" (otomatik giriş) | gerçeği AuthSession actor'u, testte sahtesi verilir
protocol SessionRestoring {
    func restore() async throws -> LoginUser?
}
