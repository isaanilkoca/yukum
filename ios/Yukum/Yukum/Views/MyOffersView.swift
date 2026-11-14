//
//  MyOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: MyOffersView (Tekliflerim, Taşımacı) ──────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Bekleyenler bölümü       →  viewModel.pendingOffers (offers'tan)  →  OfferService.myOffers()      →  GET /api/v1/offers/mine          →  [CarrierOffer]
// │ Geçmiş bölümü            →  viewModel.historyOffers (offers'tan)  →  (aynı çağrı)                  →  (aynı)                           →  [CarrierOffer]
// │ "Yeni" rozeti            →  CarrierOffer.isNew ← loadAndMarkSeen()  →  OfferService.markSeen()     →  POST /api/v1/offers/mine/seen    →  (yok)
// │ Sil (kaydırınca)         →  viewModel.canHide(_:) / hide(_:)    →  OfferService.hide()             →  DELETE /api/v1/offers/{id}       →  (yok)
// │ Sohbet düğmesi           →  viewModel.canChat(_:) / openChat(_:) → chat = ChatContext.forCarrier     →  (ChatView açılır)                →  ChatContext
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Taşımacı'nın tüm teklifleri = "Tekliflerim". İki bölüm: BEKLEYENLER (karar bekleyen) ve GEÇMİŞ (kabul/red/tamamlanan/iptal). Bitmiş olanları silebilir.
// MVVM: bu dosya yalnız GÖRÜNÜM. Liste, bölümler, silme kuralları, sohbet bilgisi ViewModels/OfferListViewModels.swift → MyOffersViewModel'de.
// BAĞLANTI: Views/HomeView.swift → Taşımacı'nın sağ üst kutu ikonu (rozetli) bu ekranı açar | kalıp: Models/Offers/ → CarrierOffer
// ⮕ KULLANIM [MyOffersView]: kullanır: HomeView › body
struct MyOffersView: View {
    @State private var viewModel = MyOffersViewModel()
    @State private var feedback: ActionFeedback? // Taşımacı işlemi → lastik izi ⮕ Design/ActionFeedback.swift
    @State private var cancelOffer: CarrierOffer? // dolunca iptal talebi sayfası açılır (karşılıklı iptal, 15 Kasım)
    @State private var busy = false   // liste içi işlem sürüyor → üstte "İşleniyor…" (Design/FormStyle › busyIndicator)
    @State private var loaded = false // ilk yükleme bitti mi → bitmeden "Henüz yok" yerine "Yükleniyor…" (LoadingCard)
    @Environment(\.colorScheme) private var colorScheme

    // GÖRÜNÜM (15 Kasım, L tasarım): ScreenBackground + yarı şeffaf kartlar, durum rozeti, kapsül düğmeler. İŞLEV DEĞİŞMEDİ.
    // İŞLEM SONRASI (Taşımacı işareti = lastik izi): geri çekme, tutar değiştirme, aşama ilerletme, silme. Yalnız BAŞARIDA.
    var body: some View {
        @Bindable var viewModel = viewModel

        List {
            if let errorMessage = viewModel.errorMessage {
                FormMessage(text: errorMessage, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if viewModel.offers.isEmpty && !loaded {
                LoadingCard().listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else if viewModel.offers.isEmpty {
                EmptyStateCard(icon: "tray", title: "Henüz teklif vermedin.", detail: "Bir ilana teklif verince burada takip edersin.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if !viewModel.pendingOffers.isEmpty {
                Section { ForEach(viewModel.pendingOffers) { offer in offerRow(offer) } } header: { sectionTitle("Bekleyenler") }
            }
            if !viewModel.historyOffers.isEmpty {
                Section { ForEach(viewModel.historyOffers) { offer in offerRow(offer) } } header: { sectionTitle("Geçmiş") }
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .busyIndicator(busy)
        .refreshable { await viewModel.load() }
        .navigationTitle("Tekliflerim")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAndMarkSeen(); loaded = true } // açılınca "görüldü" işaretlenir → ana ekrandaki rozet söner
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) }
        .alert("Tutarı değiştir", isPresented: Binding(get: { viewModel.editingOffer != nil }, set: { if !$0 { viewModel.editingOffer = nil } })) {
            TextField("Yeni tutar (₺)", text: $viewModel.editAmountText).keyboardType(.numberPad)
            Button("Kaydet") {
                if let offer = viewModel.editingOffer {
                    run(offer, "Tutar güncellendi") { await viewModel.saveAmount(offer) } // ⮕ MyOffersViewModel.saveAmount
                }
            }
            Button("Vazgeç", role: .cancel) {}
        }
        .sheet(item: $cancelOffer) { offer in // ⮕ Views/CancelRequestSheet.swift
            CancelRequestSheet(title: offer.listingTitle, isShipper: false) { reason, note, _ in
                let ok = await viewModel.requestCancel(offer, reason: reason, note: note) // ⮕ MyOffersViewModel.requestCancel
                if ok { feedback = ActionFeedback(.unload, "İptal talebi gönderildi") }
                return ok
            }
        }
        .actionFeedback($feedback)
    }

    // İşlemi çalıştırır; hata yoksa lastik izi geçer (Taşımacı işareti)
    // kind: .track (olumlu: aşama, tutar) | .unload (olumsuz: geri çekme, silme → kamyondan koli iner)
    private func run(_ offer: CarrierOffer, _ message: String, kind: ActionFeedback.Kind = .track, _ work: @escaping () async -> Void) {
        Task {
            busy = true
            await work()
            busy = false
            if viewModel.errorMessage == nil { feedback = ActionFeedback(kind, message) }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        let palette = Palette(isDark: colorScheme == .dark)
        return Text(text).font(.subheadline.weight(.bold)).foregroundStyle(palette.title).textCase(nil) // .textCase(nil) [SWIFT]: bölüm başlığı BÜYÜK HARF olmasın
    }

    @ViewBuilder
    private func offerRow(_ offer: CarrierOffer) -> some View {
        let palette = Palette(isDark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(offer.listingTitle).font(.headline).foregroundStyle(palette.title).lineLimit(1)
                if offer.isNew { // karar yeni geldi, henüz görülmedi
                    Text("Yeni").font(.caption2.bold()).foregroundStyle(palette.buttonText)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(palette.accent, in: .capsule)
                }
                Spacer()
                Text("\(Int(offer.amount)) ₺").font(.headline).foregroundStyle(palette.accent)
            }
            RouteLine(from: offer.fromCityName, fromDistrict: offer.fromDistrictName, to: offer.toCityName, toDistrict: offer.toDistrictName)
            Text("Yük Veren: \(offer.shipperName) · \(offer.weightKg) kg · \(RouteCard.trDate(offer.pickupDate))").font(.caption).foregroundStyle(palette.label.opacity(0.7))

            HStack(spacing: 8) {
                switch offer.status {
                case "Accepted": StatusBadge(text: "Kabul edildi · \(viewModel.stage(offer).title)", icon: "checkmark.circle.fill", color: palette.success)
                case "Rejected": StatusBadge(text: "Reddedildi", icon: "xmark.circle.fill", color: palette.danger)
                case "Cancelled": StatusBadge(text: offer.mutuallyCancelled == true ? "Karşılıklı iptal" : "İlan kaldırıldı", icon: offer.mutuallyCancelled == true ? "hand.raised.fill" : "trash", color: palette.label.opacity(0.7))
                case "Withdrawn": StatusBadge(text: "Geri çekildi", icon: "arrow.uturn.backward", color: palette.label.opacity(0.7))
                case "Completed": StatusBadge(text: "Tamamlandı", icon: "flag.checkered", color: palette.label.opacity(0.75))
                default: StatusBadge(text: "Beklemede", icon: "hourglass", color: palette.accent)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                // Aşama ilerletme (Yüklendi → Yolda → Teslim edildi) | ⮕ MyOffersViewModel.advance → PUT /api/v1/offers/{id}/stage
                if viewModel.canAdvance(offer), let title = viewModel.stage(offer).advanceTitle {
                    Button { run(offer, title) { await viewModel.advance(offer) } } label: { Label(title, systemImage: "truck.box.fill") }
                        .buttonStyle(ChipButtonStyle(.accent))
                }
                if viewModel.canChat(offer) {
                    Button { viewModel.openChat(offer) } label: { Label("Sohbet", systemImage: "bubble.left.and.bubble.right.fill") }.buttonStyle(ChipButtonStyle(.outline))
                }
            }

            // KARŞILIKLI İPTAL (15 Kasım): açık talep varsa kart, yoksa (uygunsa) "İptal talep et"
            if let request = offer.cancelRequest {
                CancelRequestCard(request: request, otherSide: "Yük Veren",
                                  onWithdraw: { run(offer, "Talep geri çekildi") { _ = await viewModel.withdrawCancel(offer) } },
                                  onApprove: { run(offer, "İş iptal edildi", kind: .unload) { _ = await viewModel.approveCancel(offer) } },
                                  onReject: { run(offer, "İş devam ediyor") { _ = await viewModel.rejectCancel(offer) } })
            } else if viewModel.canRequestCancel(offer) {
                Button { cancelOffer = offer } label: { Label("İptal talep et", systemImage: "xmark.circle") }.buttonStyle(ChipButtonStyle(.danger))
            }
        }
        .themedRow() // ⮕ Design/FormStyle.swift
        .swipeActions { // kaydırınca: bekleyende Geri çek / Tutarı değiştir, bitmişte Sil (kurallar ViewModel'de)
            if viewModel.canWithdraw(offer) {
                Button("Geri çek") { run(offer, "Teklif geri çekildi", kind: .unload) { await viewModel.withdraw(offer) } }.tint(palette.danger)
                Button("Tutarı değiştir") { viewModel.startEditing(offer) }.tint(palette.accent)
            }
            if viewModel.canHide(offer) {
                Button("Sil", role: .destructive) { run(offer, "Listeden silindi", kind: .unload) { await viewModel.hide(offer) } }
            }
        }
    }
}

#Preview {
    NavigationStack { MyOffersView() }
}
