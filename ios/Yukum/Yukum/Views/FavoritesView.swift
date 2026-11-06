//
//  FavoritesView.swift
//  Yukum
//

import SwiftUI

// ┌─ BAĞLANTI HARİTASI: FavoritesView ───────────────────────────────────────────────
// │ VIEWMODEL : ViewModels/FavoritesViewModel | açan: Views/HomeView (Taşımacı) sol üst kalp ikonu
// │ Liste  →  viewModel.listings  →  ListingService.favorites  →  GET /api/v1/listings/favorites  →  [Listing]
// │ Satır  →  Views/ListingRow (HomeView ile aynı satır) | basınca Views/ListingDetailView | kaydırınca "Çıkar" → viewModel.remove
// └──────────────────────────────────────────────────────────────────────

struct FavoritesView: View {
    @State private var viewModel = FavoritesViewModel() // @State [SWIFT]: ekranın hafızası

    var body: some View {
        VStack {
            if let message = viewModel.errorMessage { Text(message).foregroundColor(.red) }

            if viewModel.listings.isEmpty {
                Text("Henüz favori ilanın yok.").foregroundColor(.secondary).padding() // boşsa yönlendirici yazı
                Spacer()
            } else {
                List(viewModel.listings) { listing in
                    NavigationLink { // satıra basınca detay ekranı açılır
                        ListingDetailView(listing: listing)
                    } label: {
                        ListingRow(listing: listing)
                    }
                    .swipeActions { // sola kaydırınca "Çıkar"
                        Button("Çıkar", role: .destructive) { Task { await viewModel.remove(listing) } }
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle("Favorilerim")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() } // ekran her göründüğünde yenilenir (detaydan kalbi kapatıp dönünce güncel kalır)
    }
}
