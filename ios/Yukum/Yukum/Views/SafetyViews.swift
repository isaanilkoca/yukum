//
//  SafetyViews.swift
//  Yukum
//
//  Engelle + Şikâyet et (15 Kasım, Apple kuralı 1.2): menü düğmeleri, onaylar ve şikâyet sayfası — dört ekran ortak kullanır.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: SafetyViews ──────────────────────────────────────────────
// │ SafetyMenuItems : ekranın "⋯" menüsüne girer (ChatView'da mevcut menünün içine, diğerlerinde yeni menü)
// │ .safetyFlow(...): şikâyet sayfası + engelle onayı + "şikâyetten sonra engelle?" sorusunu ekrana bağlar
// │ ReportSheet     : neden kapsülleri (FlowChips ⮕ Views/CancelRequestSheet) + not + Gönder
// │ VIEWMODEL       : ViewModels/SafetyViewModel → SafetyService → /api/v1/users/{id}/block|report
// │ ANİMASYON       : rolün kendi dili (Design/ActionFeedback): şikâyet/engel kaldırma OLUMLU (seal/track), engelleme OLUMSUZ (unseal/unload)
// └──────────────────────────────────────────────────────────────────────

// BU GÖRÜNÜM: menüye giren iki düğme | Section [SWIFT]: menüde üstteki düğmelerden çizgiyle ayrılır
// ⮕ KULLANIM [SafetyMenuItems]: ChatView, ListingDetailView, ShipperProfileView, CarrierProfileView
struct SafetyMenuItems: View {
    let viewModel: SafetyViewModel

    var body: some View {
        Section {
            Button("Şikâyet Et", systemImage: "exclamationmark.bubble") { viewModel.showReport = true }
            if viewModel.isBlocked {
                Button("Engeli Kaldır", systemImage: "hand.raised.slash") { viewModel.showBlockConfirm = true }
            } else {
                Button("Engelle", systemImage: "hand.raised.fill", role: .destructive) { viewModel.showBlockConfirm = true }
            }
        }
    }
}

extension View {
    // .safetyFlow: menünün açtığı her şeyi ekrana bağlar | isShipper: animasyon dili (Yük Veren koli, Taşımacı kamyon)
    // onBlocked: engelleme başarılı + animasyon bitince (sohbet / ilan detayı kapanır; profillerde boş bırakılır)
    // ⮕ KULLANIM [safetyFlow]: ChatView, ListingDetailView, ShipperProfileView, CarrierProfileView
    func safetyFlow(_ viewModel: SafetyViewModel, isShipper: Bool, feedback: Binding<ActionFeedback?>, onBlocked: (() -> Void)? = nil) -> some View {
        modifier(SafetyFlow(viewModel: viewModel, isShipper: isShipper, feedback: feedback, onBlocked: onBlocked))
    }
}

// ViewModifier [SWIFT]: birden çok .sheet/.confirmationDialog'u tek satırla ekrana takmak için paket
private struct SafetyFlow: ViewModifier {
    @Bindable var viewModel: SafetyViewModel // @Bindable [SWIFT]: @Observable sınıfın alanlarına $ ile bağlanmak (sheet/dialog açık mı)
    let isShipper: Bool
    @Binding var feedback: ActionFeedback?
    let onBlocked: (() -> Void)?

    func body(content: Content) -> some View {
        let name = viewModel.target.name
        content
            .task { await viewModel.load() } // menü "Engelle" mi "Engeli Kaldır" mı yazsın
            .sheet(isPresented: $viewModel.showReport) {
                ReportSheet(name: name, isListing: viewModel.target.listingId != nil) { reason, note in
                    let error = await viewModel.report(reasonTitle: reason, note: note) // ⮕ SafetyViewModel.report → POST /users/{id}/report
                    if error == nil {
                        // sayfa kapandıktan sonra: olumlu animasyon → biter bitmez "engellemek ister misin?" (zaten engelliyse sorulmaz)
                        feedback = ActionFeedback(isShipper ? .seal : .track, "Şikâyetin alındı") {
                            if !viewModel.isBlocked { viewModel.askBlockAfterReport = true }
                        }
                    }
                    return error
                }
            }
            .confirmationDialog(viewModel.isBlocked ? "\(name) için engel kaldırılsın mı?" : "\(name) engellensin mi?",
                                isPresented: $viewModel.showBlockConfirm, titleVisibility: .visible) {
                if viewModel.isBlocked {
                    Button("Engeli Kaldır") { Task { await apply(false) } }
                } else {
                    Button("Engelle", role: .destructive) { Task { await apply(true) } }
                }
                Button("Vazgeç", role: .cancel) { }
            } message: {
                Text(viewModel.isBlocked
                     ? "Yeniden mesajlaşabilir, ilanları görebilirsiniz."
                     : "Birbirinize mesaj yazamazsınız ve teklif alışverişi yapamazsınız. Devam eden bir iş varsa kendiliğinden iptal olmaz; karşılıklı iptal talep edebilirsin. Engeli Profil → Engellediklerim'den kaldırabilirsin.")
            }
            .confirmationDialog("Şikâyetin alındı. \(name) engellensin mi?", isPresented: $viewModel.askBlockAfterReport, titleVisibility: .visible) {
                Button("Engelle", role: .destructive) { Task { await apply(true) } }
                Button("Şimdi değil", role: .cancel) { }
            }
            .alert("İşlem yapılamadı", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
                Button("Tamam", role: .cancel) { }
            } message: { Text(viewModel.errorMessage ?? "") }
    }

    // Engelle / kaldır → başarıda rolün animasyonu (engel: olumsuz, kaldırma: olumlu) → engellediyse onBlocked
    private func apply(_ block: Bool) async {
        guard await viewModel.setBlocked(block) else { return } // ⮕ SafetyViewModel.setBlocked → PUT/DELETE /users/{id}/block
        if block {
            feedback = ActionFeedback(isShipper ? .unseal : .unload, "Engellendi") { onBlocked?() }
        } else {
            feedback = ActionFeedback(isShipper ? .seal : .track, "Engel kaldırıldı")
        }
    }
}

// BU GÖRÜNÜM: şikâyet sayfası | yapı CancelRequestSheet ile aynı (neden kapsülleri + açıklama + düğme)
// onSend → String?: hata mesajı (nil = başarılı → sayfa kapanır)
// ⮕ KULLANIM [ReportSheet]: SafetyFlow (.sheet)
struct ReportSheet: View {
    let name: String
    let isListing: Bool // ilan detayından mı açıldı → başlık "ilanı şikâyet et"
    let onSend: (_ reason: String, _ note: String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var reason = ReportReason.fraud.title
    @State private var note = ""
    @State private var sending = false
    @State private var errorMessage: String?

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(isListing ? "\(name) adlı kullanıcının ilanını şikâyet et" : "\(name) adlı kullanıcıyı şikâyet et")
                        .font(.title3.bold()).foregroundStyle(palette.title)
                    Text("Şikâyetin incelenir; karşı tarafa kimin şikâyet ettiği söylenmez.")
                        .font(.footnote).foregroundStyle(palette.label.opacity(0.75))

                    FormCard { // ⮕ Design/FormStyle.swift
                        Text("Neden").font(.footnote.weight(.semibold)).foregroundStyle(palette.label)
                        FlowChips(items: ReportReason.allCases.map(\.title), selected: $reason) // ⮕ Views/CancelRequestSheet.swift › FlowChips
                        LabeledInput(label: "Açıklama (isteğe bağlı)", systemImage: "text.bubble.fill") {
                            // axis: .vertical [SWIFT]: yazı uzadıkça kutu aşağı büyür (en çok 6 satır görünür)
                            TextField("Ne oldu? Kısaca anlat.", text: $note, axis: .vertical).lineLimit(2...6)
                        }
                    }
                    if let errorMessage { FormMessage(text: errorMessage, isError: true) }

                    Button {
                        Task {
                            sending = true
                            errorMessage = await onSend(reason, note)
                            sending = false
                            if errorMessage == nil { dismiss() }
                        }
                    } label: { AccentButtonLabel(title: "Şikâyeti gönder", isLoading: sending, loadingTitle: "Gönderiliyor…") }
                    .disabled(sending)
                }
                .padding(20)
            }
            .background { ScreenBackground() }
            .navigationTitle("Şikâyet Et")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
