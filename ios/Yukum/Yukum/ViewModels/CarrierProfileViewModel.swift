//
//  CarrierProfileViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: CarrierProfileViewModel ─────────────────────────────────────
// │ EKRAN     : Views/CarrierProfileView (@State private var viewModel) | açan: ListingOffersView ve OldOffersView ("Profil")
// │ SERVİS    : Models/Services/Protocols/ReviewServicing → ReviewService | API: GET /api/v1/carriers/{id}
// │ MODEL     : CarrierProfile (+ CarrierReview) | AKIŞ: View .task → load() → servis → API → profile → @Observable → View çizer
// └──────────────────────────────────────────────────────────────────────

@Observable // @Observable [SWIFT]: değişkenleri değişince onları okuyan ekran kendiliğinden yenilenir
final class CarrierProfileViewModel {
    let carrierId: String // hangi Taşımacı | API adresine girer
    private let service: ReviewServicing // sözleşmeye bağlı: testte sahte servis verilir

    var profile: CarrierProfile? // dolana kadar nil → View "yükleniyor" gösterir
    var errorMessage: String? // sunucu/ağ hatası yazısı
    var isLoading = false

    init(carrierId: String, service: ReviewServicing = ReviewService()) {
        self.carrierId = carrierId
        self.service = service
    }

    // load: profili çeker | ÇAĞIRAN: View .task (ekran açılınca) ve .refreshable (aşağı çekince)
    // ZİNCİR: ReviewService.carrierProfile → GET /api/v1/carriers/{id} → CarrierProfile → profile
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false } // defer [SWIFT]: fonksiyon nasıl biterse bitsin (başarı/hata) en sonda çalışır
        do { profile = try await service.carrierProfile(id: carrierId) }
        catch { if let message = error.userMessage { errorMessage = message } } // iptal ise (nil) yazı gösterilmez
    }
}
