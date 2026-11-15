//
//  ForgotPasswordView.swift
//  Yukum
//
//  Şifremi unuttum (15 Kasım): iki adım — kod iste, kod + yeni şifre.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ForgotPasswordView ───────────────────────────────────────
// │ AÇAN      : LoginView "Şifremi unuttum" (.sheet) — e-posta/telefon ve hesap türü giriş ekranından dolu gelir
// │ VIEWMODEL : ViewModels/ForgotPasswordViewModel → POST /auth/password/forgot · /auth/password/reset
// │ BİTİNCE   : onDone() → LoginView yeşil "Şifren değişti" yazısı | sunucu tüm cihazlardaki oturumları kapattı
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [ForgotPasswordView]: LoginView
struct ForgotPasswordView: View {
    @State private var viewModel: ForgotPasswordViewModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(emailOrPhone: String, role: LoginRole, onDone: @escaping () -> Void) {
        _viewModel = State(initialValue: ForgotPasswordViewModel(emailOrPhone: emailOrPhone, role: role))
        self.onDone = onDone
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(viewModel.step == .request ? "Şifreni mi unuttun?" : "Yeni şifreni belirle").font(.title2.bold()).foregroundStyle(palette.title)
                    Text(viewModel.step == .request
                         ? "Hesabının e-posta ya da telefonunu yaz; kayıtlı e-postana 6 haneli kod gönderelim."
                         : "E-postana gelen kodu ve yeni şifreni yaz. Şifre değişince tüm cihazlarda oturumun kapanır.")
                        .font(.subheadline).foregroundStyle(palette.label.opacity(0.8))

                    FormCard { // ⮕ Design/FormStyle.swift
                        if viewModel.step == .request {
                            Picker("Hesap türü", selection: $viewModel.role) { // aynı e-posta iki rolde olabilir
                                ForEach(LoginRole.allCases) { role in Text(role.title).tag(role) }
                            }
                            .pickerStyle(.segmented)
                            LabeledInput(label: "E-posta veya telefon", systemImage: "envelope.fill") {
                                TextField("E-posta ya da telefon numaran", text: $viewModel.emailOrPhone).accessibilityIdentifier("forgot.identity")
                                    .textInputAutocapitalization(.never).keyboardType(.emailAddress)
                            }
                        } else {
                            LabeledInput(label: "Kod", systemImage: "number") {
                                TextField("000000", text: $viewModel.code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                            }
                            LabeledInput(label: "Yeni şifre", systemImage: "lock.fill") {
                                SecureField("En az 8 karakter, büyük-küçük harf ve rakam", text: $viewModel.newPassword).textContentType(.newPassword)
                            }
                            LabeledInput(label: "Yeni şifre (tekrar)", systemImage: "lock.fill") {
                                SecureField("Aynı şifreyi tekrar yaz", text: $viewModel.confirmPassword).textContentType(.newPassword)
                            }
                        }
                        if let error = viewModel.errorMessage { FormMessage(text: error, isError: true) }

                        Button {
                            Task {
                                if viewModel.step == .request { await viewModel.sendCode() } // ⮕ ForgotPasswordViewModel.sendCode
                                else if await viewModel.reset() { dismiss(); onDone() }        // ⮕ ForgotPasswordViewModel.reset
                            }
                        } label: {
                            AccentButtonLabel(title: viewModel.step == .request ? "Kod gönder" : "Şifreyi değiştir",
                                              isLoading: viewModel.isLoading, loadingTitle: "Gönderiliyor…")
                        }
                        .disabled(viewModel.isLoading)

                        if viewModel.step == .reset {
                            Button("Kod gelmedi, tekrar gönder") { Task { await viewModel.sendCode() } }
                                .font(.footnote.weight(.semibold)).tint(palette.accent).frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
            }
            .background { ScreenBackground() }
            .navigationTitle("Şifremi Unuttum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } } }
        }
    }
}
