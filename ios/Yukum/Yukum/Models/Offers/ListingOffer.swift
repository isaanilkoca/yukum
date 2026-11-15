//
//  ListingOffer.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ListingOffer (ilana gelen teklif, Yük Veren) ────────────────
// │ MODEL     : Yük Veren'in ilanına gelen BEKLEYEN tek teklif: taşımacı adı, tutar, not, durum
// │ ÜRETEN    : Models/Services/OfferService.listingOffers ← GET /api/v1/listings/{id}/offers
// │ SAKLAYAN  : ViewModels/ListingOffersViewModel.offers → Views/ListingOffersView (List, Kabul/Reddet/Sohbet)
// │ SOHBET    : ViewModels/ChatContext.forShipperPending(_:) bu modelden sohbet açılış bilgisi üretir
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [ListingOffer]: kullanır: ChatContext › forShipperPending(), ListingOffersViewModel › offers, ListingOffersViewModel › decide(), ListingOffersViewModel › openChat(), OfferService › listingOffers(), OfferServicing › listingOffers() … +2
struct ListingOffer: Decodable, Identifiable { // Identifiable [SWIFT]: benzersiz id'si var, List'te id: yazmak gerekmez | Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir
    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: String // teklif numarası (GUID yazı gelir) | kabul/reddet uçlarına bu gider
    // ⮕ KULLANIM [carrierName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let carrierName: String // teklifi veren taşımacının adı
    // ⮕ KULLANIM [amount]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let amount: Double // tutar | API 48000.0 gönderir
    // ⮕ KULLANIM [note]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let note: String? // isteğe bağlı not, yoksa nil
    // ⮕ KULLANIM [status]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let status: String // "Pending" / "Accepted" / "Rejected" (API durumu yazı olarak gönderir)
    let carrierId: String // Taşımacı'nın numarası | NE İŞE YARAR: tıklayınca profiline gitmek için
    let carrierRating: Double // ortalama puan (0 = henüz puan yok) | API decimal(3,2) gönderir, Double'a çözülür
    let carrierRatingCount: Int // kaç kişi puan verdi | 0 ise "Yeni" yazılır, yıldız çizilmez
    // 15 Kasım: teklifteki araç + teslim tarihi + Taşımacı'nın tamamlanan işi | eski tekliflerde nil (sıralamada sona düşer)
    var vehicleType: String? = nil
    var vehicleBrand: String? = nil
    var vehicleModel: String? = nil
    var vehicleYear: Int? = nil
    var estimatedDeliveryDate: String? = nil // "yyyy-MM-dd"
    var carrierCompletedJobCount: Int? = nil

    // "Tır · Mercedes-Benz Actros · 2019" | araç bilgisi yoksa nil
    var vehicleText: String? {
        guard let vehicleType else { return nil }
        let type = VehicleType(rawValue: vehicleType)?.title ?? vehicleType
        let name = [vehicleBrand, vehicleModel].compactMap { $0 }.joined(separator: " ")
        return [type, name.isEmpty ? nil : name, vehicleYear.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }
}
