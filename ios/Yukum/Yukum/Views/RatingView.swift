//
//  RatingView.swift
//  Yukum
//

import SwiftUI

// ┌─ BAĞLANTI HARİTASI: RatingView ──────────────────────────────────────────────────
// │ VIEWMODEL : ViewModels/RatingViewModel | açan: OldOffersView (.sheet) ve ChatView (işi bitirince .sheet)
// │ Yıldızlar / yorum  →  viewModel.rating, comment  →  "Gönder"  →  viewModel.submit()  →  ReviewService.create  →  POST /api/v1/offers/{id}/review
// └──────────────────────────────────────────────────────────────────────

struct RatingView: View {
    @State private var viewModel: RatingViewModel
    @Environment(\.dismiss) private var dismiss // dismiss [SWIFT]: sayfayı kapatır

    init(offerId: String, carrierName: String) {
        _viewModel = State(initialValue: RatingViewModel(offerId: offerId, carrierName: carrierName))
    }

    var body: some View {
        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile iki yönlü bağ kurar (TextField doğrudan viewModel.comment'e yazar)
        @Bindable var viewModel = viewModel
        NavigationStack {
            Form {
                Section("\(viewModel.carrierName) için puan ver") {
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { star in // 1...5 [SWIFT]: kapalı aralık | her yıldız için bir düğme
                            Button { viewModel.rating = star } label: {
                                Image(systemName: star <= viewModel.rating ? "star.fill" : "star") // SF Symbols: dolu/boş yıldız
                                    .font(.title).foregroundColor(.orange)
                            }
                            .buttonStyle(.borderless) // Form içinde satırın her yeri düğme olmasın
                        }
                    }
                }
                Section("Yorum (isteğe bağlı)") {
                    TextField("Nasıl bir deneyimdi?", text: $viewModel.comment, axis: .vertical).lineLimit(3...6) // axis: .vertical [SWIFT]: çok satırlı yazı
                }
                if let message = viewModel.errorMessage { Text(message).foregroundColor(.red) }
            }
            .navigationTitle("Puan Ver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Şimdi değil") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Gönder") { Task { if await viewModel.submit() { dismiss() } } } // başarılıysa kapanır
                        .bold().disabled(viewModel.isSending) // gönderilirken kilitli
                }
            }
        }
    }
}
