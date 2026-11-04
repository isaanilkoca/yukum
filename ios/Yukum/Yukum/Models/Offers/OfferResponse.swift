//
//  OfferResponse.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: OfferResponse (teklif verme cevabı) ─────────────────────────
// │ MODEL     : Teklif kaydedilince sunucunun döndüğü özet (tutar)
// │ ÜRETEN    : Services/OfferService.create ← Networking/APIClient
// │ TÜKETEN   : ViewModels/ListingDetailViewModel.submit(): yalnız başarıyı kullanır
// └──────────────────────────────────────────────────────────────────────

// Gelen cevap. Decodable [SWIFT]: JSON → struct'a çevrilebilir. Yalnız ihtiyacımız olan alanı aldık.
// FONKSİYON ROLÜ: GELEN cevap kalıbı | OfferService.create API cevabını (JSON) buna çevirip ListingDetailView'a döner
struct OfferResponse : Decodable {
    let amount : Double // API tutarı 1200.0 gibi ondalıklı gönderir, Int değil Double okunur
}


// Yük Veren'in gördüğü tek teklif satırı (GET /api/v1/listings/{id}/offers listesindeki her eleman).
// BAĞLANTI: OfferService.listingOffers bu struct'ın listesini döner → Views/ListingOffersView.swift'te liste olarak gösterilir
