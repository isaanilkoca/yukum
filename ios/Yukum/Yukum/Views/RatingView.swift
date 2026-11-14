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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var feedback: ActionFeedback? // puan Yük Veren'den gelir → koli bantlanır ⮕ Design/ActionFeedback.swift

    init(offerId: String, carrierName: String) {
        _viewModel = State(initialValue: RatingViewModel(offerId: offerId, carrierName: carrierName))
    }

    // GÖRÜNÜM (15 Kasım, L tasarım): ScreenBackground + FormCard; büyük turuncu yıldızlar (basınca hafif büyür). İŞLEV DEĞİŞMEDİ.
    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(viewModel.carrierName) için puan ver").font(.title3.bold()).foregroundStyle(palette.title)
                    FormCard { // ⮕ Design/FormStyle.swift
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { viewModel.rating = star } } label: {
                                    Image(systemName: star <= viewModel.rating ? "star.fill" : "star")
                                        .font(.system(size: 34)).foregroundStyle(palette.accent)
                                        .scaleEffect(star == viewModel.rating ? 1.15 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        LabeledInput(label: "Yorum (isteğe bağlı)", systemImage: "text.bubble.fill") {
                            TextField("Nasıl bir deneyimdi?", text: $viewModel.comment)
                        }
                    }
                    if let message = viewModel.errorMessage { FormMessage(text: message, isError: true) }
                    Button {
                        Task {
                            if await viewModel.submit() { // ⮕ RatingViewModel.submit → POST /api/v1/offers/{id}/review
                                feedback = ActionFeedback(.seal, "Puanın kaydedildi") { dismiss() }
                            }
                        }
                    } label: { AccentButtonLabel(title: "Gönder", isLoading: viewModel.isSending, loadingTitle: "Gönderiliyor…") }
                    .disabled(viewModel.isSending)
                }
                .padding(20)
            }
            .background { ScreenBackground() }
            .navigationTitle("Puan Ver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Şimdi değil") { dismiss() } } }
            .actionFeedback($feedback)
        }
    }
}
