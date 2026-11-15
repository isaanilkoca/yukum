//
//  CreateOfferRequest.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: CreateOfferRequest (teklif verme paketi) ────────────────────
// │ MODEL     : Teklif vermek için GİDEN paket: tutar + not
// │ DOLDURAN  : ViewModels/ListingDetailViewModel.submit() (amountText → Int, note boşsa nil)
// │ YOL       : Views/ListingDetailView → ListingDetailViewModel → Models/Services/OfferService.create → POST /api/v1/listings/{id}/offers
// │ CEVAP     : OfferResponse
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: teklif paketlerinin kalıpları. Gönderilecek paket + gelen cevap.
// BAĞLANTI: Models/Services/OfferService.swift bu kalıpları kullanır | API: POST /api/v1/listings/{id}/offers

// Giden paket. Encodable [SWIFT]: struct → JSON'a çevrilebilir.
// FONKSİYON ROLÜ: GİDEN paket kalıbı | ListingDetailView düğmesi doldurur, OfferService.create JSON'a çevirip API'ye yollar
// ⮕ KULLANIM [CreateOfferRequest]: kullanır: ListingDetailViewModel › submit(), OfferService › create(), OfferServicing › create(), FakeOfferService (test)
struct CreateOfferRequest : Encodable {
    
    // ⮕ KULLANIM [amount]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let amount: Int // teklif tutarı TL | API'deki "amount" ile aynı ad olmalı    l
    // ⮕ KULLANIM [note]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let note: String? // isteğe bağlı not | ?: boş olabilir, nil ise JSON'a yazılmaz
    // 15 Kasım: hangi araçla + ne zaman teslim (Yük Veren bunlara göre sıralar) | sunucu: CreateOfferHandler
    var vehicleId: String? = nil          // nil: tek aracı varsa sunucu onu seçer
    var estimatedDeliveryDate: String? = nil // "yyyy-MM-dd" (sunucu DateOnly) | yükleme tarihi ile +90 gün arası
    
}
