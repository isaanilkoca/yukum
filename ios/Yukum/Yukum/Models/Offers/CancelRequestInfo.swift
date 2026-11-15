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
// 15 Kasım (kullanıcı: "Yük Veren'in araç arızası saçma"): neden listesi ROLE GÖRE ayrıldı — herkes yalnız KENDİ tarafında olabilecek nedeni seçer.
// SUNUCU: neden serbest metin olarak saklanır (Offer.CancelReason, en çok 60 karakter; CancelRequestHandlers.cs) → liste değişince backend/migration gerekmez.
//   Karşı taraf nedeni bildirimde ve CancelRequestCard'da AYNEN görür ("Taşımacı iptal istiyor: Araç arızası").
// ⮕ KULLANIM [CancelReasons]: CancelRequestSheet (isShipper'a göre)
enum CancelReasons {
    // Yük Veren: yükün/siparişin kendisiyle ya da Taşımacı'yla ilgili nedenler
    static let shipper = ["Yük hazır değil", "Sevkiyat iptal oldu", "Tarih değişti", "Fiyat anlaşmazlığı", "Taşımacıya ulaşılamıyor", "Diğer"]
    // Taşımacı: araç, yükün tarifi ya da Yük Veren'le ilgili nedenler
    static let carrier = ["Araç arızası", "Yük tarif edildiği gibi değil", "Tarih uymadı", "Fiyat anlaşmazlığı", "Yük Veren'e ulaşılamıyor", "Diğer"]

    static func list(isShipper: Bool) -> [String] { isShipper ? shipper : carrier }

    // Açıklama kutusundaki silik örnek: seçilen nedene uygun (rol karışmasın)
    static func placeholder(for reason: String) -> String {
        switch reason {
        case "Araç arızası": return "ör. motor arıza verdi, servisteyim"
        case "Yük tarif edildiği gibi değil": return "ör. ağırlık ilandakinin iki katı"
        case "Yük hazır değil": return "ör. üretim 1 hafta gecikti"
        case "Sevkiyat iptal oldu": return "ör. alıcı siparişi iptal etti"
        case "Tarih değişti", "Tarih uymadı": return "ör. yükleme gelecek haftaya kaldı"
        case "Fiyat anlaşmazlığı": return "ör. ek masraf çıktı"
        case "Diğer": return "Kısaca nedenini yaz"
        default: return "Kısaca açıkla"
        }
    }
}
