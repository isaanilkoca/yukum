//
//  ListingDetailViewModel.swift
//  Yukum
//

import Foundation
import Observation

// BU SINIF: ilan detay ekranındaki TEKLİF formunun durumu ve mantığı (tutar, not, doğrulama, gönderme, hata)
// BAĞLANTI: Views/ListingDetailView.swift kullanır | servis: Services/OfferService.swift (OfferServicing) | paket kalıbı: Models/Offers/ → CreateOfferRequest
@Observable
final class ListingDetailViewModel {

    let listing: Listing // teklif verilen ilan
    private let service: OfferServicing

    var amountText = "" // kullanıcının yazdığı tutar | TextField yazıyla çalıştığı için String, göndermeden önce Int'e çevrilir
    var note = "" // isteğe bağlı not
    var errorMessage: String?
    var isLoading = false

    // Bu sınır sunucudaki sınırla AYNI (en fazla 100.000.000 ₺): aşırı büyük değer sunucuda 400 verirdi, burada daha ekranda yakalanır
    static let maxAmount = 100_000_000

    var hasExistingOffer: Bool { listing.myOfferAmount != nil } // daha önce teklif verdiyse düğme "Güncelle" der
    var buttonTitle: String { hasExistingOffer ? "Teklifi Güncelle" : "Teklifi Gönder" }

    init(listing: Listing, service: OfferServicing = OfferService()) {
        self.listing = listing
        self.service = service
    }

    // submit: Teklifi Gönder | -> Bool: başarılı mı (ekran başarılıysa ana sayfaya döner)
    func submit() async -> Bool {
        // 1) Kontrol: Int(amountText) yazıyı sayıya çevirir, çeviremezse nil
        guard let amount = Int(amountText.trimmingCharacters(in: .whitespaces)), amount > 0 else {
            errorMessage = "Geçerli bir tutar gir."
            return false
        }
        guard amount <= Self.maxAmount else {
            errorMessage = "Teklif tutarı en fazla 100.000.000 ₺ olabilir."
            return false
        }
        // 2) Paketi hazırla | not boşsa nil gönder (JSON'a hiç yazılmaz), doluysa baş/son boşluğu temizlenmiş yazı
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = CreateOfferRequest(amount: amount, note: trimmedNote.isEmpty ? nil : trimmedNote)

        isLoading = true // düğme kilitlenir
        errorMessage = nil
        defer { isLoading = false }
        // 3) Gönder
        do {
            _ = try await service.create(listingId: listing.id, body)
            return true
        } catch {
            if let message = error.userMessage { errorMessage = message } // örn. "Bu ilan artık teklif almıyor."
            return false
        }
    }
}
