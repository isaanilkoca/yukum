//
//  OldOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: OldOffersView (Eski Teklifler, Yük Veren) ─────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Teklif listesi           →  viewModel.offers ← load()           →  OfferService.shipperHistory()   →  GET /api/v1/offers/history       →  [ShipperHistoryOffer]
// │ Sil (kaydırınca)         →  viewModel.canHide(_:) / hide(_:)    →  OfferService.hide()             →  DELETE /api/v1/offers/{id}       →  (yok)
// │ Sohbet düğmesi           →  viewModel.openChat(_:)              →  chat = ChatContext.forShipperHistory →  (ChatView açılır)           →  ChatContext
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Yük Veren'in karara bağladığı (kabul/red/tamamlanan) tüm teklifler = "Eski teklifler". Bitmiş olanları kaydırıp kendi listesinden silebilir.
// Kabul edilen teklifin sohbetine buradan ulaşılır (aktif iş: silinemez, sohbet açık, "İşi Bitir ve Sil" sohbetin menüsünde).
// MVVM: bu dosya yalnız GÖRÜNÜM. Liste, silme kuralı, sohbet bilgisi ViewModels/OfferListViewModels.swift → OldOffersViewModel'de.
// BAĞLANTI: Views/HomeView.swift → Yük Veren'in sol üst saat ikonu bu ekranı açar | kalıp: Models/Offers/ → ShipperHistoryOffer
// ⮕ KULLANIM [OldOffersView]: kullanır: HomeView › body
struct OldOffersView: View {
    // 15 Kasım: .active "Devam Eden İşler" (kabul edilmiş, bitmemiş) | .history "Eski Teklifler" (sonuçlananlar) | nil: hepsi (eski görünüm)
    var scope: OfferScope? = nil
    @State private var viewModel = OldOffersViewModel()
    @State private var feedback: ActionFeedback? // Yük Veren işlemi → koli bantlanır ⮕ Design/ActionFeedback.swift
    @State private var cancelOffer: ShipperHistoryOffer?  // dolunca iptal talebi sayfası (karşılıklı iptal, 15 Kasım)
    @State private var approveOffer: ShipperHistoryOffer? // dolunca "ilan ne olsun?" seçimi (onay Yük Veren'deyse ilanı o seçer)
    @State private var busy = false   // liste içi işlem sürüyor → üstte "İşleniyor…" (Design/FormStyle › busyIndicator)
    @State private var loaded = false // ilk yükleme bitti mi → bitmeden "Henüz yok" yerine "Yükleniyor…" (LoadingCard)
    @Environment(\.colorScheme) private var colorScheme

    // GÖRÜNÜM (15 Kasım, L tasarım): ScreenBackground + yarı şeffaf kartlar, durum rozeti, kapsül düğmeler. İŞLEV DEĞİŞMEDİ.
    // İŞLEM SONRASI: kaydırıp "Sil" başarılıysa koli bantlanır.
    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)

        List {
            if let errorMessage = viewModel.errorMessage {
                FormMessage(text: errorMessage, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if viewModel.offers.isEmpty && !loaded {
                LoadingCard().listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else if viewModel.offers.isEmpty {
                EmptyStateCard(icon: "clock.arrow.circlepath", title: "Henüz karar verdiğin teklif yok", detail: "Kabul ettiğin ya da reddettiğin teklifler burada durur.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if loaded, !viewModel.offers.isEmpty, let scope, !viewModel.offers.contains(where: { scope.contains(status: $0.status) }) {
                EmptyStateCard(icon: scope == .active ? "shippingbox" : "clock.arrow.circlepath",
                               title: scope == .active ? "Devam eden işin yok" : "Sonuçlanmış teklif yok",
                               detail: scope == .active ? "Bir teklifi kabul edince iş burada takip edilir." : nil)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(viewModel.offers.filter { scope?.contains(status: $0.status) ?? true }) { offer in // ⮕ OfferScope (MyOffersViewModel.swift)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(offer.listingTitle).font(.headline).foregroundStyle(palette.title).lineLimit(1)
                        Spacer()
                        Text("\(Int(offer.amount)) ₺").font(.headline).foregroundStyle(palette.accent)
                    }
                    RouteLine(from: offer.fromCityName, fromDistrict: offer.fromDistrictName, to: offer.toCityName, toDistrict: offer.toDistrictName) // ⮕ Design/FormStyle.swift
                    Text("Taşımacı: \(offer.carrierName) · \(offer.weightKg) kg · \(RouteCard.trDate(offer.pickupDate))").font(.caption).foregroundStyle(palette.label.opacity(0.7))
                    HStack(spacing: 8) {
                        switch offer.status { // durum rozeti: renk + simge
                        case "Accepted": StatusBadge(text: "Kabul ettin · \(viewModel.stageTitle(offer))", icon: "checkmark.circle.fill", color: palette.success)
                        case "Completed": StatusBadge(text: "Tamamlandı", icon: "flag.checkered", color: palette.label.opacity(0.75))
                        case "Cancelled": StatusBadge(text: offer.mutuallyCancelled == true ? "Karşılıklı iptal" : "İptal edildi", icon: "hand.raised.fill", color: palette.label.opacity(0.7))
                        default: StatusBadge(text: "Reddettin", icon: "xmark.circle.fill", color: palette.danger)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        if viewModel.canRate(offer) {
                            Button { viewModel.ratingOffer = offer } label: { Label("Puan ver", systemImage: "star.fill") }.buttonStyle(ChipButtonStyle(.accent)) // ⮕ RatingView
                        }
                        Button { viewModel.openChat(offer) } label: { Label("Sohbet", systemImage: "bubble.left.and.bubble.right.fill") }.buttonStyle(ChipButtonStyle(.outline))
                        Button { viewModel.profileCarrierId = offer.carrierId } label: { Label("Profil", systemImage: "person.fill") }.buttonStyle(ChipButtonStyle(.outline))
                    }

                    // KARŞILIKLI İPTAL (15 Kasım): açık talep varsa kart, yoksa (uygunsa) "İptal talep et"
                    if let request = offer.cancelRequest {
                        CancelRequestCard(request: request, otherSide: "Taşımacı",
                                          onWithdraw: { act("Talep geri çekildi", .seal) { _ = await viewModel.withdrawCancel(offer) } },
                                          onApprove: { approveOffer = offer }, // önce ilanın ne olacağı sorulur (aşağıdaki seçim penceresi)
                                          onReject: { act("İş devam ediyor", .seal) { _ = await viewModel.rejectCancel(offer) } })
                    } else if viewModel.canRequestCancel(offer) {
                        Button { cancelOffer = offer } label: { Label("İptal talep et", systemImage: "xmark.circle") }.buttonStyle(ChipButtonStyle(.danger))
                    }
                }
                .themedRow() // ⮕ Design/FormStyle.swift
                .swipeActions { // reddedilmiş ve tamamlanmışlar silinebilir (kural ViewModel'de)
                    if viewModel.canHide(offer) {
                        Button("Sil", role: .destructive) {
                            Task {
                                busy = true
                                await viewModel.hide(offer) // ⮕ OldOffersViewModel.hide
                                busy = false
                                if viewModel.errorMessage == nil { feedback = ActionFeedback(.unseal, "Listeden silindi") }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .busyIndicator(busy)
        .refreshable { await viewModel.load() }
        .navigationTitle(scope == .active ? "Devam Eden İşler" : "Eski Teklifler")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(); loaded = true }
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) }
        .navigationDestination(item: $viewModel.profileCarrierId) { id in CarrierProfileView(carrierId: id) }
        .sheet(item: $viewModel.ratingOffer, onDismiss: { Task { await viewModel.load() } }) { offer in
            RatingView(offerId: offer.id, carrierName: offer.carrierName) // ⮕ Views/RatingView.swift
        }
        .sheet(item: $cancelOffer) { offer in // ⮕ Views/CancelRequestSheet.swift (Yük Veren: ilanın ne olacağını burada seçer)
            CancelRequestSheet(title: offer.listingTitle, isShipper: true) { reason, note, reopen in
                let ok = await viewModel.requestCancel(offer, reason: reason, note: note, reopenListing: reopen ?? true)
                if ok { feedback = ActionFeedback(.unseal, "İptal talebi gönderildi") }
                return ok
            }
        }
        // Taşımacı'nın talebini onaylarken ilanın ne olacağını Yük Veren seçer (kullanıcı kararı)
        .confirmationDialog("İş iptal edilsin mi?", isPresented: Binding(get: { approveOffer != nil }, set: { if !$0 { approveOffer = nil } }), titleVisibility: .visible) {
            Button("Onayla ve ilanı yeniden yayınla") { if let o = approveOffer { act("İş iptal edildi, ilan yayında", .unseal) { _ = await viewModel.approveCancel(o, reopenListing: true) } } }
            Button("Onayla ve ilanı kaldır", role: .destructive) { if let o = approveOffer { act("İş iptal edildi", .unseal) { _ = await viewModel.approveCancel(o, reopenListing: false) } } }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Yeniden yayınlarsan ilan yeni teklif alır; kaldırırsan yayından çıkar.")
        }
        .actionFeedback($feedback)
    }

    // İşlemi çalıştırır: "İşleniyor…" + başarıda animasyon (Yük Veren: koli)
    private func act(_ message: String, _ kind: ActionFeedback.Kind, _ work: @escaping () async -> Void) {
        Task {
            busy = true
            await work()
            busy = false
            if viewModel.errorMessage == nil { feedback = ActionFeedback(kind, message) }
        }
    }
}

#Preview {
    NavigationStack { OldOffersView() }
}
