//
//  CreateOfferRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: CreateOfferRequest (teklif verme paketi) ────────────────────
// │ MODEL     : Teklif vermek için GİDEN paket: tutar + not
// │ DOLDURAN  : ViewModels/ListingDetailViewModel.submit() (amountText → Int, note boşsa nil)
// │ YOL       : Views/ListingDetailView → ListingDetailViewModel → Services/OfferService.create → POST /api/v1/listings/{id}/offers
// │ CEVAP     : OfferResponse
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: teklif paketlerinin kalıpları. Gönderilecek paket + gelen cevap.
// BAĞLANTI: Services/OfferService.swift bu kalıpları kullanır | API: POST /api/v1/listings/{id}/offers

// Giden paket. Encodable [SWIFT]: struct → JSON'a çevrilebilir.
// FONKSİYON ROLÜ: GİDEN paket kalıbı | ListingDetailView düğmesi doldurur, OfferService.create JSON'a çevirip API'ye yollar
struct CreateOfferRequest : Encodable {
    
    let amount: Int // teklif tutarı TL | API'deki "amount" ile aynı ad olmalı    l
    let note: String? // isteğe bağlı not | ?: boş olabilir, nil ise JSON'a yazılmaz
    
}
