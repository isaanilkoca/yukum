//
//  MyOffersViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: MyOffersViewModel ───────────────────────────────────────────
// │ EKRAN     : Views/MyOffersView (@State private var viewModel) — Taşımacı'nın "Tekliflerim"i; Views/HomeView sağ üst kutu ikonu açar
// │ SERVİS    : Services/Protocols/OfferServicing → OfferService.myOffers / markSeen / hide
// │ MODEL     : CarrierOffer | sohbet için ChatContext
// │ AKIŞ      : View .task → loadAndMarkSeen() → myOffers → offers → pending/history bölümleri | Sil → hide() → load()
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: "Tekliflerim" (Taşımacı) ekranının durumu ve mantığı: teklif listesi, Bekleyenler/Geçmiş bölümleri, silme ve sohbet kuralları, "görüldü" işaretleme
// BAĞLANTI: Views/MyOffersView.swift kullanır | servis: Services/OfferService.swift (OfferServicing sözleşmesi) | sohbet bilgisi: ViewModels/ChatContext.swift
// ⮕ KULLANIM [MyOffersViewModel]: kullanır: MyOffersView › viewModel, MyOffersViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class MyOffersViewModel {
    // ⮕ KULLANIM [service]: okur: MyOffersViewModel › load(), MyOffersViewModel › loadAndMarkSeen(), MyOffersViewModel › hide()
    private let service: OfferServicing

    // ⮕ ZİNCİR: Views/MyOffersView: pendingOffers/historyOffers bundan türer | DOLDURAN: load() ← OfferService.myOffers() | MODEL: [CarrierOffer]
    // ⮕ KULLANIM [offers]: okur: MyOffersViewModel › pendingOffers, MyOffersViewModel › historyOffers, MyOffersView › body, MyOffersViewModelTests (test) | YAZAR: MyOffersViewModel › load()
    var offers: [CarrierOffer] = []
    // ⮕ ZİNCİR: Views/MyOffersView: if let errorMessage → kırmızı yazı | load()/hide() catch'leri
    // ⮕ KULLANIM [errorMessage]: YAZAR: MyOffersViewModel › load(), MyOffersViewModel › hide() | okur: MyOffersViewModelTests (test)
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/MyOffersView: .navigationDestination(item: $viewModel.chat) { ChatView(context:) } — dolunca sohbet açılır, nil olunca kapanır | DOLDURAN: openChat(_:)
    // ⮕ KULLANIM [chat]: YAZAR: MyOffersViewModel › openChat() | bağlar(okur+yazar): MyOffersView › body | okur: MyOffersViewModelTests (test)
    var chat: ChatContext? // dolunca ekran sohbeti açar (.navigationDestination(item:)), nil olunca kapanır | NEDEN değişken: List satırında NavigationLink düğmeleri bozar

    // İki bölüm: BEKLEYENLER (karar bekleyen) ve GEÇMİŞ (kabul/red/tamamlanan/iptal) | ana sayfada yalnız dokunulmamış ilanlar kalır, gerisi burada
    // ⮕ ZİNCİR: Views/MyOffersView: Section("Bekleyenler") { ForEach(viewModel.pendingOffers) }
    // ⮕ KULLANIM [pendingOffers]: okur: MyOffersView › body, MyOffersViewModelTests (test)
    var pendingOffers: [CarrierOffer] { offers.filter { $0.status == "Pending" } }
    // ⮕ ZİNCİR: Views/MyOffersView: Section("Geçmiş") { ForEach(viewModel.historyOffers) } — kabul/red/tamamlanan/iptal
    // ⮕ KULLANIM [historyOffers]: okur: MyOffersView › body, MyOffersViewModelTests (test)
    var historyOffers: [CarrierOffer] { offers.filter { $0.status != "Pending" } }

    init(service: OfferServicing = OfferService()) { self.service = service }

    // KURAL: yalnız BİTMİŞ teklif silinebilir (reddedilen, tamamlanan, iptal edilen) | bekleyen: karar yok | kabul edilen: AKTİF İŞ (API de 409 verir)
    // ⮕ ZİNCİR: Views/MyOffersView: .swipeActions { if viewModel.canHide(offer) { "Sil" } } — yalnız reddedilen/tamamlanan/iptal
    // ⮕ KULLANIM [canHide]: çağırır: MyOffersView › offerRow(), MyOffersViewModelTests (test)
    func canHide(_ offer: CarrierOffer) -> Bool { ["Rejected", "Completed", "Cancelled"].contains(offer.status) } // .contains [SWIFT]: içinde var mı diye bakar
    // KURAL: reddedilen teklifte sohbet yok | bekleyen, kabul, tamamlanan, iptalde düğme çıkar (kapalı olanlarda yalnız eski mesajlar okunur/silinir)
    // ⮕ ZİNCİR: Views/MyOffersView: if viewModel.canChat(offer) { "Sohbet" düğmesi } — reddedilende yok
    // ⮕ KULLANIM [canChat]: çağırır: MyOffersView › offerRow(), MyOffersViewModelTests (test)
    func canChat(_ offer: CarrierOffer) -> Bool { offer.status != "Rejected" }

    // ⮕ ZİNCİR: Views/MyOffersView: .refreshable ve hide() sonrası | OfferService.myOffers()
    // ⮕ KULLANIM [load]: çağırır: MyOffersViewModel › loadAndMarkSeen(), MyOffersViewModel › hide(), MyOffersView › body, MyOffersViewModelTests (test)
    func load() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        errorMessage = nil
        do { offers = try await service.myOffers() } // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
        catch { if let message = error.userMessage { errorMessage = message } }
    }

    // loadAndMarkSeen: ekran açılınca | ÖNCE listeyi çek ("Yeni" rozetleri çizilsin), SONRA "görüldü" yap (rozet söner)
    // ⮕ ZİNCİR: Views/MyOffersView: .task | önce load() ("Yeni" rozetleri çizilsin), sonra OfferService.markSeen() (HomeView rozeti söner)
    // ⮕ KULLANIM [loadAndMarkSeen]: çağırır: MyOffersView › body, MyOffersViewModelTests (test)
    func loadAndMarkSeen() async {
        await load()
        try? await service.markSeen() // try?: hata olursa sessiz geç, kritik değil | try? [SWIFT]: hata olursa çökme, nil ver
    }

    // ⮕ ZİNCİR: Views/MyOffersView: Button("Sil") { Task { await viewModel.hide(offer) } } | OfferService.hide(offerId:) sonra load()
    // ⮕ KULLANIM [hide]: çağırır: MyOffersViewModel › hide(), MyOffersView › offerRow(), MyOffersViewModelTests (test)
    func hide(_ offer: CarrierOffer) async {
        errorMessage = nil
        do {
            try await service.hide(offerId: offer.id)
            await load() // silindi, liste yenilenir
        } catch {
            if let message = error.userMessage { errorMessage = message } // örn. "Kabul edilmiş teklif aktif iştir; önce "İşi bitir" denmeli."
        }
    }

    // ⮕ ZİNCİR: Views/MyOffersView: Button("Sohbet") { viewModel.openChat(offer) } | chat = ChatContext.forCarrier(offer)
    // ⮕ KULLANIM [openChat]: çağırır: MyOffersView › offerRow(), MyOffersViewModelTests (test)
    func openChat(_ offer: CarrierOffer) { chat = ChatContext.forCarrier(offer) }
}
