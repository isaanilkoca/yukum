//
//  SafetyServicing.swift
//  Yukum
//

import Foundation

// Engelle/şikâyet servisinin sözleşmesi (15 Kasım) | ViewModel somut sınıfa değil buna bağlıdır, testte sahtesi verilir
// ⮕ KULLANIM [SafetyServicing]: SafetyViewModel, BlockedUsersViewModel
protocol SafetyServicing {
    func block(userId: String) async throws
    func unblock(userId: String) async throws
    func blocked() async throws -> [BlockedUser]
    func report(userId: String, _ body: ReportUserRequest) async throws
}
