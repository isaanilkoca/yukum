//
//  ChatContext.swift
//  Yukum
//

import Foundation

// ChatContext: bir sohbetin AÇILIŞ BİLGİSİ | hangi teklif, başlıkta kim yazsın, yazılabilir mi, bitirilebilir mi
// NEDEN ayrı struct: "kim hangi durumda yazabilir/bitirebilir" kuralı eskiden üç ekranda ayrı ayrı yazılıydı (ChatView(offerId:title:canComplete:canWrite:) çağrıları).
//   Artık kural TEK YERDE (aşağıdaki üç fonksiyon) ve testle doğrulanır (YukumTests/ChatViewModelTests.swift)
// Hashable [SWIFT]: .navigationDestination(item:) seçili öğeyi bununla takip eder
// BAĞLANTI: MyOffersViewModel, ListingOffersViewModel, OldOffersViewModel üretir | View/ChatView.swift alır
struct ChatContext: Hashable {
    let offerId: String // hangi teklifin sohbeti | API adresine girer /offers/{offerId}/messages
    let title: String // üst çubuktaki başlık (karşı tarafın adı)
    let canComplete: Bool // "İşi Bitir ve Sil" seçeneği çıksın mı | yalnız KABUL EDİLMİŞ (aktif) işte
    let canWrite: Bool // yazma kutusu açık mı | reddedilmiş/tamamlanmış/iptal edilmişte kapalı, yalnız eski mesajlar okunur (API de 409 verir)

    // Taşımacı kendi teklifinin sohbetini açıyor (Tekliflerim): yazı yalnız bekleyen ve kabul edilende, bitirme yalnız kabul edilende
    static func forCarrier(_ offer: CarrierOffer) -> ChatContext {
        ChatContext(offerId: offer.id, title: offer.shipperName,
                    canComplete: offer.status == "Accepted", canWrite: offer.status == "Pending" || offer.status == "Accepted")
    }

    // Yük Veren, ilanına gelen BEKLEYEN bir teklifle pazarlık ediyor (Gelen Teklifler): yazılabilir, henüz bitirilemez
    static func forShipperPending(_ offer: ListingOffer) -> ChatContext {
        ChatContext(offerId: offer.id, title: offer.carrierName, canComplete: false, canWrite: true)
    }

    // Yük Veren, karara bağlanmış bir teklifin sohbetini açıyor (Eski Teklifler): yazı ve bitirme yalnız kabul edilende
    static func forShipperHistory(_ offer: ShipperHistoryOffer) -> ChatContext {
        ChatContext(offerId: offer.id, title: offer.carrierName,
                    canComplete: offer.status == "Accepted", canWrite: offer.status == "Accepted")
    }
}
