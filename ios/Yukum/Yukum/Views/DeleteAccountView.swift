//
//  DeleteAccountView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 11.11.2026.
//


import SwiftUI


// ┌─ BAĞLANTI HARİTASI: DeleteAccountView ───────────────────────────────────────────
// │ VIEWMODEL : ViewModels/AccountViewModel | açan: Views/HomeView (.sheet, "Hesabı Sil" düğmesi)
// │ Şifre kutusu  →  viewModel.password  →  "Hesabımı Sil"  →  viewModel.deleteAccount()  →  AccountService  →  POST /api/v1/account/delete
// │ Başarı        →  onDeleted() (HomeView verir: kendini kapatır → LoginView'a döner)


struct DeleteAccountView: View {
    
    @State private var viewModel = AccountViewModel()
    @Environment(\.dismiss) private var dismiss // ismiss bu sayfayı kapatır
    let onDeleted : () -> Void // closure [SWIFT]: "hesap silinince çalışacak iş" | HomeView verir (kendi ekranını kapatır) | () -> Void: parametresiz, değer döndürmez
    
    @Environment(\.colorScheme) private var colorScheme

    // GÖRÜNÜM (15 Kasım, L tasarım): ScreenBackground + uyarı kartı + şifre kutusu (LabeledInput) + kiremit renkli silme düğmesi.
    //   İŞLEV DEĞİŞMEDİ: aynı ViewModel (şifre, deleteAccount), başarıda onDeleted. Animasyon YOK (hesap silmek kutlanacak bir işlem değil).
    var body: some View {
        @Bindable var viewModel = viewModel
        let palette = Palette(isDark: colorScheme == .dark)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bu işlem geri alınamaz", systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundStyle(palette.danger)
                        Text("Hesabın kalıcı olarak kapatılır. Açık ilanların kaldırılır, bekleyen tekliflerin iptal olur, favorilerin silinir.").font(.subheadline).foregroundStyle(palette.title)
                        Text("Devam eden bir işin varsa önce onu tamamlaman gerekir.").font(.footnote).foregroundStyle(palette.label.opacity(0.7))
                    }
                    .themedCard()
                    FormCard { // ⮕ Design/FormStyle.swift
                        LabeledInput(label: "Onay için şifreni gir", systemImage: "lock.fill") {
                            SecureField("Şifre", text: $viewModel.password) // ⮕ AccountViewModel.password
                        }
                    }
                    if let message = viewModel.errorMessage { FormMessage(text: message, isError: true) }
                    Button(role: .destructive) {
                        Task { if await viewModel.deleteAccount() { onDeleted() } } // ⮕ AccountViewModel.deleteAccount → DELETE /api/v1/account
                    } label: {
                        Text("Hesabımı Sil").font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(palette.danger, in: .rect(cornerRadius: 14))
                    }
                    .disabled(viewModel.isDeleting)
                }
                .padding(20)
            }
            .background { ScreenBackground() }
            .navigationTitle("Hesabı Sil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } } }
        }
    }
}
