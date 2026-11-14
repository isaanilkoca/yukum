//
//  CancelRequestInfo.swift
//  Yukum
//
//  Karşılıklı iptal (15 Kasım): kabul edilmiş işte açık iptal talebinin bilgisi + gönderilen istek gövdeleri.
//

import Foundation // [SWIFT] temel türler

// ┌─ BAĞLANTI HARİTASI: CancelRequestInfo ─────────────────────────────────────────
// │ GELEN  : API → CarrierOffer.cancelRequest (Tekliflerim) | ShipperHistoryOffer.cancelRequest (Eski Teklifler)
// │ GİDEN  : OfferService.requestCancel / approveCancel (CancelRequestBody / CancelApproveBody)
// │ SUNUCU : backend Application/Offers/CancelRequestHandlers.cs (kurallar orada)
// └──────────────────────────────────────────────────────────────────────

// BU TÜR: açık iptal talebi | null gelirse açık talep yok
// ⮕ KULLANIM [CancelRequestInfo]: CarrierOffer, ShipperHistoryOffer, MyOffersView, OldOffersView
struct CancelRequestInfo: Decodable, Equatable {
    let byMe: Bool          // talebi ben mi açtım → true: "Talebin bekleniyor / geri çek" | false: "Onayla / Reddet"
    let reason: String      // "Araç arızası" gibi kısa neden
    let note: String?       // isteğe bağlı açıklama
    let requestedAt: String // ISO tarih (şimdilik gösterilmiyor)
}

// BU TÜR: talep gövdesi | reopenListing: yalnız Yük Veren gönderir (onaylanınca ilan yeniden yayınlansın mı)
struct CancelRequestBody: Encodable { let reason: String; let note: String?; let reopenListing: Bool? }

// BU TÜR: onay gövdesi | reopenListing: onaylayan Yük Veren ise ilanın ne olacağı (Taşımacı onaylıyorsa nil: Yük Veren'in talepteki seçimi geçerli)
struct CancelApproveBody: Encodable { let reopenListing: Bool? }

// Sabit neden listesi (talep sayfasındaki seçenekler) | "Diğer" seçilirse açıklama önerilir
enum CancelReasons {
    static let all = ["Araç arızası", "Yük hazır değil", "Tarih uymadı", "Fiyat anlaşmazlığı", "Diğer"]
}
