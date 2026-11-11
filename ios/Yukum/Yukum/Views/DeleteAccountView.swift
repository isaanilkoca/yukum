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
    
    var body: some View {
        
    // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile iki yönlü bağ kurar (SecureField doğrudan viewModel.password'e yazar)
        
     @Bindable var viewModel = viewModel
        
        NavigationStack{
            
            Form{ // Form [SWIFT]: ayar tarzı gruplu liste
                Section {
                    Text("Hesabın kalıcı olarak kapatılır. Açık ilanların kaldırılır, bekleyen tekliflerin iptal olur , favorilerin silinir. Bu işlem geri alınamaz !").font(.subheadline)
                    Text("Devam eden bir işin varsa önce onu tamamlaman gerekir.").font(.footnote).foregroundColor(.secondary)
                }
                Section("Onay için şifreni gir"){
                    SecureField("Şifre", text: $viewModel.password) // securefield : yazıan nokta nokta görünür
                }
                if let message = viewModel.errorMessage {  // if let [SWIFT]: nil değilse içini aç
                    Text(message).foregroundColor(.red) // sunucu mesajı: "Şifre hatalı." / "Devam eden bir işin var..."
                }
                Section{
                    // role: .destructive [SWIFT]: kırmızı "tehlikeli işlem" düğmesi | Task { await … } [SWIFT]: düğme await çağıramaz, Task içinde çağırılır
                    Button("Hesabımı Sil",role: .destructive){
                        Task{ if await viewModel.deleteAccount() {onDeleted() }}
                    }
                    .disabled(viewModel.isDeleting)
                }
                
            }
            .navigationTitle("Hesabı Sil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{
                ToolbarItem(placement: .topBarLeading) {Button("Vazgeç") {dismiss()}}
            }
        }
        
    }
}


