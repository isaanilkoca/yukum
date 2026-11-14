//
//  FavoritesView.swift
//  Yukum
//

import SwiftUI

// ┌─ BAĞLANTI HARİTASI: FavoritesView ───────────────────────────────────────────────
// │ VIEWMODEL : ViewModels/FavoritesViewModel | açan: Views/HomeView (Taşımacı) sol üst kalp ikonu
// │ Liste  →  viewModel.listings  →  ListingService.favorites  →  GET /api/v1/listings/favorites  →  [Listing]
// │ Satır  →  Views/ListingRow › RouteCard (Taşımacı ana ekranıyla aynı kart) | basınca Views/ListingDetailView | kaydırınca "Çıkar" → viewModel.remove
// └──────────────────────────────────────────────────────────────────────

// GÖRÜNÜM (15 Kasım, L tasarım): Taşımacı ana ekranıyla aynı rota kartları (RouteCard) + ScreenBackground. İŞLEV DEĞİŞMEDİ.
// NEDEN hâlâ List (ScrollView değil): kaydırınca "Çıkar" (swipeActions) yalnız List satırlarında çalışır.
//   List'in kendi zemini ve ayırıcıları gizlendi (.scrollContentBackground, .listRowBackground, .listRowSeparator) → kart görünümü kalır.
// İŞLEM SONRASI: favoriden çıkarınca lastik izi geçer (Taşımacı işareti) ⮕ Design/ActionFeedback.swift
// ⮕ KULLANIM [FavoritesView]: kullanır: HomeView › toolbar (Taşımacı, sol üst kalp)
struct FavoritesView: View {
    @State private var viewModel = FavoritesViewModel() // @State [SWIFT]: ekranın hafızası
    @State private var feedback: ActionFeedback? // ⮕ Design/ActionFeedback.swift
    @State private var busy = false   // liste içi işlem sürüyor → üstte "İşleniyor…" (Design/FormStyle › busyIndicator)
    @State private var loaded = false // ilk yükleme bitti mi → bitmeden "Henüz yok" yerine "Yükleniyor…" (LoadingCard)
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        VStack {
            if let message = viewModel.errorMessage { FormMessage(text: message, isError: true).padding(.horizontal) } // ⮕ Design/FormStyle.swift

            if viewModel.listings.isEmpty && !loaded {
                LoadingCard().padding()
                Spacer()
            } else if viewModel.listings.isEmpty {
                VStack(spacing: 8) { // boş durum: yönlendirici
                    Image(systemName: "heart").font(.largeTitle).foregroundStyle(palette.accent.opacity(0.85))
                    Text("Henüz favori ilanın yok.").font(.headline).foregroundStyle(palette.title)
                    Text("İlan detayında kalbe basınca burada görünür.").font(.caption).foregroundStyle(palette.label.opacity(0.7))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
                .background(palette.cardSurface.opacity(0.55), in: .rect(cornerRadius: 16))
                .padding()
                Spacer()
            } else {
                List(viewModel.listings) { listing in
                    // NavigationLink'i kartın ARKASINA koyma: List içinde NavigationLink sağa gri ok ekler; RouteCard'ın kendi turuncu oku var
                    RouteCard(listing: listing) // ⮕ Views/ListingRow.swift › RouteCard
                        .background { NavigationLink { ListingDetailView(listing: listing) } label: { EmptyView() }.opacity(0) } // basınca detay
                        .listRowBackground(Color.clear) // [SWIFT] satırın beyaz zemini yok
                        .listRowSeparator(.hidden)      // [SWIFT] ayırıcı çizgi yok
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .swipeActions { // sola kaydırınca "Çıkar"
                            Button("Çıkar", role: .destructive) {
                                Task {
                                    busy = true
                                    await viewModel.remove(listing) // ⮕ FavoritesViewModel.remove → ListingService.setFavorite(false) → load()
                                    busy = false
                                    if viewModel.errorMessage == nil { feedback = ActionFeedback(.unload, "Favorilerden çıkarıldı") } // olumsuz: kamyondan koli iner
                                }
                            }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden) // [SWIFT] List'in kendi zemini gizli → ScreenBackground görünür
                .refreshable { await viewModel.load() }
            }
        }
        .background { ScreenBackground() } // ⮕ Design/ActionFeedback.swift
        .busyIndicator(busy)
        .tint(palette.accent)
        .navigationTitle("Favorilerim")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(); loaded = true } // ekran her göründüğünde yenilenir (detaydan kalbi kapatıp dönünce güncel kalır)
        .actionFeedback($feedback)
    }
}
