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
    @State private var viewModel = OldOffersViewModel()
    @State private var feedback: ActionFeedback? // Yük Veren işlemi → koli bantlanır ⮕ Design/ActionFeedback.swift
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
            if viewModel.offers.isEmpty {
                EmptyStateCard(icon: "clock.arrow.circlepath", title: "Henüz karar verdiğin teklif yok", detail: "Kabul ettiğin ya da reddettiğin teklifler burada durur.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(viewModel.offers) { offer in
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
                }
                .themedRow() // ⮕ Design/FormStyle.swift
                .swipeActions { // reddedilmiş ve tamamlanmışlar silinebilir (kural ViewModel'de)
                    if viewModel.canHide(offer) {
                        Button("Sil", role: .destructive) {
                            Task {
                                await viewModel.hide(offer) // ⮕ OldOffersViewModel.hide
                                if viewModel.errorMessage == nil { feedback = ActionFeedback(.unseal, "Listeden silindi") }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .refreshable { await viewModel.load() }
        .navigationTitle("Eski Teklifler")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) }
        .navigationDestination(item: $viewModel.profileCarrierId) { id in CarrierProfileView(carrierId: id) }
        .sheet(item: $viewModel.ratingOffer, onDismiss: { Task { await viewModel.load() } }) { offer in
            RatingView(offerId: offer.id, carrierName: offer.carrierName) // ⮕ Views/RatingView.swift
        }
        .actionFeedback($feedback)
    }
}

#Preview {
    NavigationStack { OldOffersView() }
}
