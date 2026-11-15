//
//  ChatView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ChatView (sohbet) ─────────────────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Mesaj balonları          →  viewModel.messages ← load()         →  ChatService.messages()          →  GET /api/v1/offers/{id}/messages →  [ChatMessage]
// │ Yazma kutusu             →  viewModel.draft ($ bağ)             →  (yazılır, send() okur)          →  -                                →  -
// │ Gönder düğmesi           →  viewModel.send()                    →  ChatService.send()              →  POST /api/v1/offers/{id}/messages →  SendMessageRequest
// │ Menü: Mesajları Temizle  →  viewModel.clear()                   →  ChatService.clear()             →  DELETE .../messages              →  (yok)
// │ Menü: İşi Bitir ve Sil   →  viewModel.complete()                →  ChatService.complete()          →  POST /api/v1/offers/{id}/complete →  (yok)
// │ Yazma/menü kuralları     →  viewModel.canWrite, canComplete, canSend, locked  (kural: ChatContext + locked)
// │ Otomatik yenileme        →  .task { startPolling() } → 3 sn'de bir load()  (ekran kapanınca iptal)
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: bir teklifin sohbeti. Yük Veren ile teklifi veren Taşımacı yazışır. Mesajlar balon olarak çizilir, ekran açıkken 3 sn'de bir yenilenir.
// MVVM: bu dosya yalnız GÖRÜNÜM. Mesajlar, taslak, gönderme, temizleme, işi bitirme, kilit ve yenileme döngüsü ViewModels/ChatViewModel.swift'te.
// BAĞLANTI: Views/ListingOffersView.swift (Yük Veren), Views/MyOffersView.swift (Taşımacı), Views/OldOffersView.swift (Yük Veren geçmişi) "Sohbet" düğmesiyle bu ekranı açar
//
// SOHBET MANTIĞI (4 adım):
//   1) EKRAN AÇILINCA  → mesajları API'den çek (GET)
//   2) GÖNDERİNCE      → yazıyı API'ye yolla (POST), sonra listeyi yeniden çek
//   3) KARŞI TARAFIN MESAJI → sunucu "push" yapmaz; ViewModel 3 sn'de bir tekrar sorar (polling) | canlı bağlantı yok, basit yöntem
//   4) ÇİZİM           → her mesaj isMine'a bakılıp sağa (benim) ya da sola (karşı taraf) yaslı balon olur

// ⮕ KULLANIM [ChatView]: kullanır: ListingOffersView › body, MyOffersView › body, OldOffersView › body
struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showClearConfirm = false
    @State private var showCompleteConfirm = false
    @State private var showRating = false
    @State private var feedback: ActionFeedback? // işlem sonrası animasyon (rolüne göre) ⮕ Design/ActionFeedback.swift
    @State private var busy = false // temizle / işi bitir sürüyor → "İşleniyor…"

    @State private var safety: SafetyViewModel // 15 Kasım: Engelle / Şikâyet Et ⮕ ViewModels/SafetyViewModel, Views/SafetyViews

    init(context: ChatContext) {
        _viewModel = State(initialValue: ChatViewModel(context: context))
        _safety = State(initialValue: SafetyViewModel(target: SafetyTarget(userId: context.otherUserId ?? "", name: context.title, offerId: context.offerId)))
    }

    // Rol işareti: sohbeti iki rol de açar. canReview yalnız Yük Veren'de true (ChatContext) → Yük Veren koli, Taşımacı lastik izi.
    private var feedbackKind: ActionFeedback.Kind { viewModel.context.canReview ? .seal : .track }

    // GÖRÜNÜM (15 Kasım, L tasarım): benim balonum turuncu, karşı tarafınki yarı şeffaf kart; alt çubukta kapsül yazı kutusu + yuvarlak gönder.
    //   İŞLEV DEĞİŞMEDİ: aynı yoklama (startPolling), gönderme, temizleme, işi bitirme.
    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)

        VStack(spacing: 0) {
            ScrollViewReader { proxy in // [SWIFT] koddan belirli bir mesaja kaydırmayı sağlar
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            HStack {
                                if message.isMine { Spacer(minLength: 48) }
                                Text(message.text)
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .foregroundStyle(message.isMine ? palette.buttonText : palette.title)
                                    .background(message.isMine ? palette.accent : palette.cardSurface.opacity(0.8), in: .rect(cornerRadius: 18))
                                    .overlay { if !message.isMine { RoundedRectangle(cornerRadius: 18).strokeBorder(palette.cardBorder) } }
                                if !message.isMine { Spacer(minLength: 48) }
                            }
                            .id(message.id) // scrollTo için kimlik
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in // yeni mesaj gelince en alta kay
                    if let last = viewModel.messages.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            if let errorMessage = viewModel.errorMessage { FormMessage(text: errorMessage, isError: true).padding(.horizontal) }

            if viewModel.canWrite {
                HStack(spacing: 10) {
                    TextField("Mesaj yaz", text: $viewModel.draft, axis: .vertical) // axis: .vertical → uzun mesajda kutu büyür
                        .lineLimit(1...4)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(palette.fieldSurface, in: .rect(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(palette.fieldBorder))
                        .foregroundStyle(palette.title)
                    Button { Task { await viewModel.send() } } label: { // ⮕ ChatViewModel.send → POST /api/v1/offers/{id}/messages
                        Image(systemName: "arrow.up").font(.headline.bold()).foregroundStyle(palette.buttonText)
                            .frame(width: 40, height: 40).background(palette.accent, in: .circle)
                    }
                    .disabled(!viewModel.canSend).opacity(viewModel.canSend ? 1 : 0.45)
                }
                .padding(.horizontal).padding(.vertical, 10)
                .background(palette.cardSurface.opacity(0.85))
            } else {
                Label("Bu sohbet kapalı (teklif reddedildi ya da iş tamamlandı). Eski mesajlar okunabilir.", systemImage: "lock.fill")
                    .font(.caption).foregroundStyle(palette.label.opacity(0.75)).padding()
            }
        }
        .background { ScreenBackground() } // ⮕ Design/ActionFeedback.swift
        .busyIndicator(busy)
        .navigationTitle(viewModel.context.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Mesajları Temizle", systemImage: "trash") { showClearConfirm = true }
                    if viewModel.canComplete { // yalnız kabul edilmiş + teslim edilmiş işte
                        Button("İşi Bitir ve Sil", systemImage: "checkmark.seal", role: .destructive) { showCompleteConfirm = true }
                    }
                    if viewModel.context.otherUserId != nil { SafetyMenuItems(viewModel: safety) } // Şikâyet Et + Engelle (karşı taraf biliniyorsa)
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog("Mesajlar temizlensin mi?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Benden Sil", role: .destructive) {
                Task {
                    busy = true; defer { busy = false }
                    await viewModel.clear() // ⮕ ChatViewModel.clear
                    if viewModel.errorMessage == nil { feedback = ActionFeedback(viewModel.context.canReview ? .unseal : .unload, "Mesajlar temizlendi") } // silme: rolün olumsuz animasyonu
                }
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Mesajlar yalnızca sizin ekranınızdan silinir. Karşı taraf görmeye devam eder, iş ve teklif yerinde kalır.")
        }
        .sheet(isPresented: $showRating, onDismiss: { dismiss() }) { // puan sayfası kapanınca sohbetten çık
            RatingView(offerId: viewModel.context.offerId, carrierName: viewModel.context.title)
        }
        .alert("İş bitsin mi?", isPresented: $showCompleteConfirm) {
            Button("Bitir ve Sil", role: .destructive) {
                Task {
                    busy = true; defer { busy = false }
                    if await viewModel.complete() { // ⮕ ChatViewModel.complete → işi tamamla
                        // animasyon bitince: Yük Veren puan sayfasını görür, Taşımacı sohbetten çıkar
                        feedback = ActionFeedback(feedbackKind, "İş tamamlandı") {
                            if viewModel.context.canReview { showRating = true } else { dismiss() }
                        }
                    }
                }
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("İş iki tarafta da Tamamlandı olur ve sohbet iki tarafta yazmaya kapanır. Teklif ve mesajlar sizin listenizden silinir; karşı taraf tamamlanmış işi kendi geçmişinde görür.")
        }
        .safetyFlow(safety, isShipper: viewModel.context.canReview, feedback: $feedback) { dismiss() } // engelleyince sohbetten çık ⮕ Views/SafetyViews.swift
        .task { await viewModel.startPolling() } // ekran açıkken birkaç saniyede bir yeni mesaj sorar; ekran kapanınca .task kendiliğinden durur
        .actionFeedback($feedback)
    }
}
