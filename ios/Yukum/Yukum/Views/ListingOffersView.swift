//
//  ListingOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ListingOffersView (Gelen Teklifler, Yük Veren) ────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ İlan başlığı             →  viewModel.listing                   →  (HomeView'dan gelir)            →  -                                →  Listing
// │ Bekleyen teklif listesi  →  viewModel.offers ← load()           →  OfferService.listingOffers()    →  GET /api/v1/listings/{id}/offers →  [ListingOffer]
// │ Kabul et / Reddet        →  viewModel.decide(_:accept:)         →  OfferService.decide()           →  POST /api/v1/offers/{id}/accept|reject →  (yok)
// │ Sohbet düğmesi           →  viewModel.openChat(_:)              →  chat = ChatContext.forShipperPending →  (ChatView açılır)           →  ChatContext
// │ Kaldır (ilanı yayından)  →  viewModel.cancelListing()           →  ListingService.cancel()         →  POST /api/v1/listings/{id}/cancel →  (yok)
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Yük Veren kendi ilanına basınca açılır. İlana gelen BEKLEYEN teklifleri listeler (Kabul Et / Reddet / Sohbet) ve ilanı yayından kaldırma düğmesi vardır.
// Karar verilen teklifler buradan kalkıp "Eski Teklifler"e gider.
// MVVM: bu dosya yalnız GÖRÜNÜM. Teklif listesi, karar, ilanı kaldırma ViewModels/OfferListViewModels.swift → ListingOffersViewModel'de.
// BAĞLANTI: Views/HomeView.swift → Yük Veren listesindeki NavigationLink bu ekranı açar ve ilanı verir | kalıp: Models/Offers/ → ListingOffer
// ⮕ KULLANIM [ListingOffersView]: kullanır: HomeView › body
struct ListingOffersView: View {
    @State private var viewModel: ListingOffersViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCancelConfirm = false
    @State private var feedback: ActionFeedback? // Yük Veren işlemi → koli bantlanır ⮕ Design/ActionFeedback.swift
    @State private var busy = false   // liste içi işlem sürüyor → üstte "İşleniyor…" (Design/FormStyle › busyIndicator)
    @State private var acceptedHere = false // bu ekranda bir teklif kabul edildi → ilan artık atanmış: düzenleme/kaldırma kapanır (15 Kasım kuralı)
    @State private var loaded = false // ilk yükleme bitti mi → bitmeden "Henüz yok" yerine "Yükleniyor…" (LoadingCard)

    init(listing: Listing) {
        _viewModel = State(initialValue: ListingOffersViewModel(listing: listing))
    }

    // GÖRÜNÜM (15 Kasım, L tasarım): ScreenBackground + yarı şeffaf kartlar (Design/FormStyle › themedRow, ChipButtonStyle). İŞLEV DEĞİŞMEDİ.
    // İŞLEM SONRASI (Yük Veren işareti = koli bantlanır): kabul, ret, ilanı kaldırma. Yalnız BAŞARIDA (errorMessage boş kaldıysa).
    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)

        List {
            // ÜST BİLGİ: başlık + istatistik kartları (görüntülenme, favori, teklif) | ⮕ ListingOffersViewModel.stats ← loadStats()
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.listing.title).font(.title3.bold()).foregroundStyle(palette.title)
                RouteLine(from: viewModel.listing.fromCityName, fromDistrict: viewModel.listing.fromDistrictName,
                          to: viewModel.listing.toCityName, toDistrict: viewModel.listing.toDistrictName) // ⮕ Design/FormStyle.swift
                if let stats = viewModel.stats {
                    HStack(spacing: 8) {
                        statCard("eye.fill", stats.viewCount, "Görüntülenme", palette)
                        statCard("heart.fill", stats.favoriteCount, "Favori", palette)
                        statCard("tray.full.fill", stats.offerCount, "Teklif", palette)
                    }
                }
            }
            .listRowBackground(Color.clear).listRowSeparator(.hidden)

            if let errorMessage = viewModel.errorMessage {
                FormMessage(text: errorMessage, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }

            // KABULDEN SONRA (15 Kasım, yönetici kuralı: "teklif kabul edilince ilan silinmemeli, teslim olmadan silinmemeli"):
            //   sunucu da reddeder (409); burada menü gizlenir ve nedeni yazılır → kullanıcı denemeden bilir.
            if acceptedHere {
                Label("Teklifi kabul ettin. Yük teslim edilene kadar bu ilan düzenlenemez ve kaldırılamaz. İşi Eski Teklifler'den takip edebilirsin.", systemImage: "lock.fill")
                    .font(.footnote).foregroundStyle(palette.title)
                    .themedRow()
            }

            if viewModel.offers.isEmpty && !loaded {
                LoadingCard().listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else if viewModel.offers.isEmpty {
                EmptyStateCard(icon: "tray", title: "Henüz teklif gelmedi.", detail: "Taşımacılar teklif verince burada görünür.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.offers) { offer in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(offer.carrierName).font(.headline).foregroundStyle(palette.title)
                                Text(RatingText.summary(rating: offer.carrierRating, count: offer.carrierRatingCount)).font(.caption).foregroundStyle(palette.accent) // ⮕ Models › RatingText
                            }
                            Spacer()
                            Text("\(Int(offer.amount)) ₺").font(.title3.bold()).foregroundStyle(palette.accent)
                        }
                        if let note = offer.note {
                            Text(note).font(.caption).foregroundStyle(palette.label.opacity(0.75))
                        }
                        // Düğmeler: ChipButtonStyle ZORUNLU (stilsiz düğmede List satırının her yeri düğme olur)
                        HStack(spacing: 8) {
                            Button("Kabul et") { decide(offer, accept: true) }.buttonStyle(ChipButtonStyle(.success))
                            Button("Reddet") { decide(offer, accept: false) }.buttonStyle(ChipButtonStyle(.danger))
                            Spacer(minLength: 0)
                            Button { viewModel.profileCarrierId = offer.carrierId } label: { Image(systemName: "person.fill") }.buttonStyle(ChipButtonStyle(.outline)) // ⮕ CarrierProfileView
                            Button { viewModel.openChat(offer) } label: { Image(systemName: "bubble.left.and.bubble.right.fill") }.buttonStyle(ChipButtonStyle(.outline)) // ⮕ ChatView
                        }
                    }
                    .themedRow() // ⮕ Design/FormStyle.swift
                }
            }
        }
        .listStyle(.plain)
        .themedScreen() // ⮕ Design/FormStyle.swift: ScreenBackground + List zemini gizli
        .busyIndicator(busy)
        .refreshable { await viewModel.load() }
        .navigationTitle("Gelen Teklifler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !acceptedHere { // kabul edilmiş ilanda düzenle/kaldır yok (yukarıdaki not)
                Menu { // iki eylem tek menüde: üst çubuk sıkışmasın
                    NavigationLink { CreateListingView(listing: viewModel.listing, onSaved: { dismiss() }) } label: { Label("Düzenle", systemImage: "pencil") } // ⮕ CreateListingView (düzenleme kipi)
                    Button(role: .destructive) { showCancelConfirm = true } label: { Label("Yayından kaldır", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .alert("İlan yayından kaldırılsın mı?", isPresented: $showCancelConfirm) {
            Button("Yayından Kaldır", role: .destructive) {
                Task {
                    busy = true; defer { busy = false } // defer [SWIFT]: Task'tan her çıkışta busy kapanır
                    if await viewModel.cancelListing() { // ⮕ ListingOffersViewModel.cancelListing → DELETE /api/v1/listings/{id}
                        feedback = ActionFeedback(.unseal, "İlan kaldırıldı") { dismiss() } // iptal: koli açılır + İPTAL damgası
                    }
                }
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("İlan herkesin listesinden kalkar. Gelen teklifler iptal edilir, Taşımacılar bilgilendirilir ve sohbetler kapanır.")
        }
        .task { await viewModel.load(); loaded = true; await viewModel.loadStats() }
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) }
        .navigationDestination(item: $viewModel.profileCarrierId) { id in CarrierProfileView(carrierId: id) }
        .actionFeedback($feedback)
    }

    // Kabul/ret: ViewModel karar verir; başarıdaysa koli bantlanır | ⮕ ListingOffersViewModel.decide → PUT /api/v1/offers/{id}/accept|reject
    private func decide(_ offer: ListingOffer, accept: Bool) {
        Task {
            busy = true
            await viewModel.decide(offer, accept: accept)
            busy = false
            if accept && viewModel.errorMessage == nil { acceptedHere = true }
            if viewModel.errorMessage == nil { feedback = ActionFeedback(accept ? .seal : .unseal, accept ? "Teklif kabul edildi" : "Teklif reddedildi") } // kabul: bantlanır | ret: bant kesilir
        }
    }

    // İstatistik kartı: simge + sayı + başlık
    private func statCard(_ icon: String, _ value: Int, _ title: String, _ palette: Palette) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption).foregroundStyle(palette.accent)
            Text("\(value)").font(.title3.bold()).foregroundStyle(palette.title)
            Text(title).font(.caption2).foregroundStyle(palette.label.opacity(0.7))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(palette.cardSurface.opacity(0.62), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.cardBorder))
    }
}
