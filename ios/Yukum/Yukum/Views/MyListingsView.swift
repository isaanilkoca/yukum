//
//  MyListingsView.swift
//  Yukum
//
//  İlanlarım (15 Kasım, 8. adım): profil > İlanlarım. Açık + geçmiş ilanlar, durum rozetiyle.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: MyListingsView ─────────────────────────────────────────
// │ VIEWMODEL : ViewModels/MyListingsViewModel → GET /api/v1/listings/mine?all=true
// │ AÇAN      : Views/ProfileView (Yük Veren)
// │ SATIR     : ListingRow (Views/ListingRow.swift) + StatusBadge (Design/FormStyle) | dokununca ListingOffersView (teklifler, iş durumu)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [MyListingsView]: ProfileView
struct MyListingsView: View {
    @State private var viewModel = MyListingsViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        List {
            if let message = viewModel.errorMessage {
                FormMessage(text: message, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if !viewModel.loaded {
                LoadingCard().listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else if viewModel.listings.isEmpty {
                EmptyStateCard(icon: "shippingbox", title: "Henüz ilanın yok", detail: "İlk ilanını ana ekrandaki “Yeni ilan ver” düğmesinden verebilirsin.")
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            ForEach(viewModel.listings) { listing in
                // NavigationLink: satıra dokununca ilanın teklif/iş ekranı (kaldırılmış ilanda da açılır: geçmiş teklifler görünür)
                NavigationLink { ListingOffersView(listing: listing) } label: { row(listing, palette) }
                    .themedRow() // ⮕ Design/FormStyle.swift
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .navigationTitle("İlanlarım")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func row(_ listing: Listing, _ palette: Palette) -> some View {
        let badge = MyListingsViewModel.badge(for: listing.status)
        let color: Color = switch badge.tone {
            case .accent: palette.accent
            case .success: palette.success
            case .danger: palette.danger
        }
        return VStack(alignment: .leading, spacing: 8) {
            ListingRow(listing: listing).foregroundStyle(palette.title) // ⮕ Views/ListingRow.swift (başlık, rota, tarih)
            StatusBadge(text: badge.text, icon: badge.icon, color: color)
        }
        .opacity(listing.status == "Cancelled" ? 0.7 : 1) // kaldırılmış ilan soluk: geçmişte kaldığı belli olsun
    }
}
