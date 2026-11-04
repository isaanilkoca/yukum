//
//  ChatContext.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ChatContext (sohbet açılış bilgisi) ─────────────────────────
// │ NE        : Sohbet açılırken verilen 4 bilgi: hangi teklif, başlık, bitirilebilir mi, yazılabilir mi (kural burada, tek yerde)
// │ ÜRETEN    : MyOffersViewModel.openChat | ListingOffersViewModel.openChat | OldOffersViewModel.openChat → kendi "chat" değişkenine yazar
// │ TÜKETEN   : Views/*View.navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) } → ViewModels/ChatViewModel(context:)
// │ MODEL     : CarrierOffer, ListingOffer, ShipperHistoryOffer'dan türetilir
// └──────────────────────────────────────────────────────────────────────

// ChatContext: bir sohbetin AÇILIŞ BİLGİSİ | hangi teklif, başlıkta kim yazsın, yazılabilir mi, bitirilebilir mi
// NEDEN ayrı struct: "kim hangi durumda yazabilir/bitirebilir" kuralı eskiden üç ekranda ayrı ayrı yazılıydı (ChatView(offerId:title:canComplete:canWrite:) çağrıları).
//   Artık kural TEK YERDE (aşağıdaki üç fonksiyon) ve testle doğrulanır (YukumTests/ChatViewModelTests.swift)
// Hashable [SWIFT]: .navigationDestination(item:) seçili öğeyi bununla takip eder
// BAĞLANTI: MyOffersViewModel, ListingOffersViewModel, OldOffersViewModel üretir | Views/ChatView.swift alır
// ⮕ KULLANIM [ChatContext]: kullanır: ChatViewModel › context, ChatViewModel › init(), ListingOffersViewModel › chat, ListingOffersViewModel › openChat(), MyOffersViewModel › chat, MyOffersViewModel › openChat() … +4
struct ChatContext: Hashable {
    // ⮕ KULLANIM [offerId]: okur: ChatContext › forCarrier(), ChatContext › forShipperPending(), ChatContext › forShipperHistory(), ChatViewModel › load(), ChatViewModel › send(), ChatViewModel › clear() … +2
    let offerId: String // hangi teklifin sohbeti | API adresine girer /offers/{offerId}/messages
    // ⮕ KULLANIM [title]: okur: ChatContext › forCarrier(), ChatContext › forShipperPending(), ChatContext › forShipperHistory()
    let title: String // üst çubuktaki başlık (karşı tarafın adı)
    // ⮕ KULLANIM [canComplete]: okur: ChatContext › forCarrier(), ChatContext › forShipperPending(), ChatContext › forShipperHistory()
    let canComplete: Bool // "İşi Bitir ve Sil" seçeneği çıksın mı | yalnız KABUL EDİLMİŞ (aktif) işte
    // ⮕ KULLANIM [canWrite]: okur: ChatContext › forCarrier(), ChatContext › forShipperPending(), ChatContext › forShipperHistory()
    let canWrite: Bool // yazma kutusu açık mı | reddedilmiş/tamamlanmış/iptal edilmişte kapalı, yalnız eski mesajlar okunur (API de 409 verir)

    // Taşımacı kendi teklifinin sohbetini açıyor (Tekliflerim): yazı yalnız bekleyen ve kabul edilende, bitirme yalnız kabul edilende
    // ⮕ ZİNCİR: Taşımacı kendi teklifinin sohbetini açıyor ← MyOffersViewModel.openChat(_:) ← Views/MyOffersView "Sohbet" düğmesi
    // ⮕ KULLANIM [forCarrier]: çağırır: MyOffersViewModel › openChat(), ChatViewModelTests (test)
    static func forCarrier(_ offer: CarrierOffer) -> ChatContext { // static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)
        ChatContext(offerId: offer.id, title: offer.shipperName,
                    canComplete: offer.status == "Accepted", canWrite: offer.status == "Pending" || offer.status == "Accepted")
    }

    // Yük Veren, ilanına gelen BEKLEYEN bir teklifle pazarlık ediyor (Gelen Teklifler): yazılabilir, henüz bitirilemez
    // ⮕ ZİNCİR: Yük Veren bekleyen teklifle pazarlık ediyor ← ListingOffersViewModel.openChat(_:) ← Views/ListingOffersView "Sohbet"
    // ⮕ KULLANIM [forShipperPending]: çağırır: ListingOffersViewModel › openChat(), ChatViewModelTests (test)
    static func forShipperPending(_ offer: ListingOffer) -> ChatContext {
        ChatContext(offerId: offer.id, title: offer.carrierName, canComplete: false, canWrite: true)
    }

    // Yük Veren, karara bağlanmış bir teklifin sohbetini açıyor (Eski Teklifler): yazı ve bitirme yalnız kabul edilende
    // ⮕ ZİNCİR: Yük Veren karara bağlanmış teklifin sohbetini açıyor ← OldOffersViewModel.openChat(_:) ← Views/OldOffersView "Sohbet"
    // ⮕ KULLANIM [forShipperHistory]: çağırır: OldOffersViewModel › openChat(), ChatViewModelTests (test)
    static func forShipperHistory(_ offer: ShipperHistoryOffer) -> ChatContext {
        ChatContext(offerId: offer.id, title: offer.carrierName,
                    canComplete: offer.status == "Accepted", canWrite: offer.status == "Accepted")
    }
}
