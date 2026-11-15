//
//  VerifyEmailView.swift
//  Yukum
//
//  E-posta doğrulama kodu ekranı (15 Kasım).
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: VerifyEmailView ──────────────────────────────────────────
// │ AÇAN      : LoginView .sheet(item: $viewModel.verifyTarget) — kayıttan sonra ya da doğrulanmamış hesapla girişte
// │ VIEWMODEL : ViewModels/VerifyEmailViewModel → POST /auth/verify-email · /auth/verify-email/send
// │ BİTİNCE   : onVerified() → LoginViewModel.verified (girişten geldiyse otomatik giriş)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [VerifyEmailView]: LoginView
struct VerifyEmailView: View {
    @State private var viewModel: VerifyEmailViewModel
    let onVerified: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focused: Bool // @FocusState [SWIFT]: klavye hangi alanda | açılınca kod alanına odaklanır

    init(target: VerifyTarget, onVerified: @escaping () -> Void) {
        _viewModel = State(initialValue: VerifyEmailViewModel(target: target))
        self.onVerified = onVerified
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "envelope.badge.fill").font(.system(size: 44)).foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity)
                    Text("E-postanı doğrula").font(.title2.bold()).foregroundStyle(palette.title)
                    Text("Hesabının e-posta adresine 6 haneli bir kod gönderdik. Kod 15 dakika geçerli.")
                        .font(.subheadline).foregroundStyle(palette.label.opacity(0.8))

                    FormCard { // ⮕ Design/FormStyle.swift
                        LabeledInput(label: "Doğrulama kodu", systemImage: "number") {
                            // .oneTimeCode [SWIFT]: iOS gelen kodu klavyenin üstünde önerir (Mail'den otomatik doldurma)
                            TextField("000000", text: $viewModel.code)
                                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                                .font(.title3.monospacedDigit()).focused($focused)
                        }
                        if let error = viewModel.errorMessage { FormMessage(text: error, isError: true) }
                        if let info = viewModel.infoMessage { FormMessage(text: info, isError: false) }

                        Button {
                            Task { if await viewModel.verify() { dismiss(); onVerified() } } // ⮕ VerifyEmailViewModel.verify
                        } label: { AccentButtonLabel(title: "Doğrula", isLoading: viewModel.isLoading, loadingTitle: "Doğrulanıyor…") }
                        .disabled(viewModel.isLoading)

                        // TimelineView [SWIFT]: her saniye yeniden çizer → geri sayım canlı akar (ViewModel'de zamanlayıcı yok)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let left = viewModel.secondsLeft(at: context.date)
                            Button(left > 0 ? "Kodu yeniden gönder (\(left) sn)" : "Kodu yeniden gönder") { Task { await viewModel.resend() } }
                                .font(.footnote.weight(.semibold)).tint(palette.accent)
                                .disabled(left > 0)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Text("Kod gelmediyse gereksiz (spam) klasörüne bak.").font(.caption).foregroundStyle(palette.label.opacity(0.65))
                }
                .padding(20)
            }
            .background { ScreenBackground() }
            .navigationTitle("Doğrulama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Kapat") { dismiss() } } }
            .onAppear { focused = true }
        }
    }
}
