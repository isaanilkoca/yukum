//
//  CancelRequestSheet.swift
//  Yukum
//
//  Karşılıklı iptal talebi sayfası (15 Kasım): neden seç + isteğe bağlı açıklama (+ Yük Veren için ilanın ne olacağı).
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: CancelRequestSheet ───────────────────────────────────────────
// │ AÇAN      : Views/MyOffersView (Taşımacı) | Views/OldOffersView (Yük Veren) — kabul edilmiş, teslim edilmemiş işte "İptal talep et"
// │ GÖNDER    : onSend(neden, not, ilanı yeniden yayınla?) → çağıranın ViewModel'i → OfferService.requestCancel → POST /api/v1/offers/{id}/cancel-request
// │ KURAL     : karşı taraf onaylamadıkça iş sürer (backend CancelRequestHandlers)
// └──────────────────────────────────────────────────────────────────────

// NEDEN ayrı sayfa (uyarı penceresi değil): neden seçimi + açıklama + Yük Veren'in ilan seçimi tek uyarıya sığmıyor; yanlışlıkla basılmasın.
// ⮕ KULLANIM [CancelRequestSheet]: MyOffersView, OldOffersView (.sheet)
struct CancelRequestSheet: View {
    let title: String                  // ilan başlığı (hangi iş)
    let isShipper: Bool                // Yük Veren mi → ilan seçimi görünür
    let onSend: (_ reason: String, _ note: String?, _ reopenListing: Bool?) async -> Bool // başarılıysa true → sayfa kapanır

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var reason = "" // ilk açılışta rolün ilk nedeni seçilir (.onAppear) | ⮕ Models/Offers/CancelRequestInfo.swift
    @State private var note = ""
    @State private var reopen = true // Yük Veren: onaylanınca ilan yeniden yayınlansın (varsayılan: evet, yük havada kalmasın)
    @State private var sending = false

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("“\(title)” işi için iptal talebi").font(.title3.bold()).foregroundStyle(palette.title)
                    Text("Karşı taraf onaylarsa iş iptal olur. Onaylanana kadar iş devam eder.")
                        .font(.footnote).foregroundStyle(palette.label.opacity(0.75))

                    FormCard { // ⮕ Design/FormStyle.swift
                        Text("Neden").font(.footnote.weight(.semibold)).foregroundStyle(palette.label)
                        // Neden kapsülleri: dokununca seçilir (seçili olan turuncu)
                        FlowChips(items: CancelReasons.list(isShipper: isShipper), selected: $reason) // rolün kendi nedenleri
                        LabeledInput(label: "Açıklama (isteğe bağlı)", systemImage: "text.bubble.fill") {
                            TextField(CancelReasons.placeholder(for: reason), text: $note)
                        }
                        if isShipper {
                            Toggle(isOn: $reopen) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Onaylanınca ilanı yeniden yayınla").font(.subheadline.weight(.semibold)).foregroundStyle(palette.title)
                                    Text(reopen ? "Yük yeniden teklif alır." : "İlan yayından kaldırılır.").font(.caption).foregroundStyle(palette.label.opacity(0.7))
                                }
                            }
                            .tint(palette.accent)
                        }
                    }

                    Button {
                        Task {
                            sending = true
                            let ok = await onSend(reason, note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note, isShipper ? reopen : nil)
                            sending = false
                            if ok { dismiss() }
                        }
                    } label: { AccentButtonLabel(title: "İptal talebi gönder", isLoading: sending, loadingTitle: "Gönderiliyor…") }
                    .disabled(sending)
                }
                .padding(20)
            }
            .background { ScreenBackground() }
            .navigationTitle("İptal Talebi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } } }
        }
        .presentationDetents([.medium, .large]) // [SWIFT] yarım ekran açılır, istenirse büyütülür
        .onAppear { if reason.isEmpty { reason = CancelReasons.list(isShipper: isShipper)[0] } } // rolün ilk nedeni seçili gelir
    }
}

// BU GÖRÜNÜM: sarmalanan seçim kapsülleri (satıra sığmayan alta geçer)
// ⮕ KULLANIM [FlowChips]: CancelRequestSheet
struct FlowChips: View {
    let items: [String]
    @Binding var selected: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        // ViewThatFits yerine basit iki sütunlu ızgara: 5 kısa seçenek, her ekranda düzgün
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let on = item == selected
                Button { selected = item } label: {
                    Text(item).font(.footnote.weight(.semibold))
                        .foregroundStyle(on ? palette.buttonText : palette.title)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(on ? palette.accent : palette.fieldSurface, in: .capsule)
                        .overlay(Capsule().strokeBorder(on ? .clear : palette.fieldBorder))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// BU GÖRÜNÜM: kartın içindeki açık iptal talebi kutusu | talebi ben açtıysam "bekleniyor + geri çek", karşı taraf açtıysa "Onayla / Reddet"
// ⮕ KULLANIM [CancelRequestCard]: MyOffersView, OldOffersView
struct CancelRequestCard: View {
    let request: CancelRequestInfo
    let otherSide: String          // karşı tarafın adı ("Yük Veren" / "Taşımacı")
    let onWithdraw: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 8) {
            Label(request.byMe ? "İptal talebin \(otherSide)'in onayını bekliyor" : "\(otherSide) iptal istiyor: \(request.reason)",
                  systemImage: request.byMe ? "hourglass" : "exclamationmark.bubble.fill")
                .font(.footnote.weight(.bold)).foregroundStyle(palette.danger)
            if request.byMe { Text("Neden: \(request.reason)").font(.caption).foregroundStyle(palette.label.opacity(0.8)) }
            if let note = request.note { Text("“\(note)”").font(.caption).foregroundStyle(palette.label.opacity(0.8)) }
            HStack(spacing: 8) {
                if request.byMe {
                    Button("Talebi geri çek", action: onWithdraw).buttonStyle(ChipButtonStyle(.outline))
                } else {
                    Button("Onayla", action: onApprove).buttonStyle(ChipButtonStyle(.danger))
                    Button("Reddet", action: onReject).buttonStyle(ChipButtonStyle(.outline))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.danger.opacity(0.08), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.danger.opacity(0.3)))
    }
}
