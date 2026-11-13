//
//  ContentView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ContentView ──────────────────────────────────────────────────
// │ GELEN     : App/YukumApp.swift → WindowGroup { ContentView() }
// │ GİDEN     : Views/LoginView.swift (uygulamanın ilk ekranı) → oradan ViewModels/LoginViewModel.restoreSession() otomatik girişi dener
// │ NOT       : Genel proje haritası ve iz sürme rehberi App/YukumApp.swift'in başındadır
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: uygulamanın ilk ekran kapısı. Şimdilik sadece LoginView'a yönlendirir.
// BAĞLANTI: YukumApp.swift bu ekranı açar → burası Views/LoginView.swift'i gösterir.
// ⮕ KULLANIM [ContentView]: kullanır: YukumApp › body
struct ContentView: View { // ContentView [BİZİM] ad | View [SWIFT]: "bu struct bir ekrandır" sözleşmesi
    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View { // body [SWIFT] zorunlu: ekranın içeriği | some View: "bir ekran parçası döner"
        #if DEBUG // [SWIFT] yalnız geliştirme derlemesinde derlenir; App Store sürümünde bu blok YOKTUR
        // PROTOTİP KAPISI (geçici): "-truckPreview" argümanıyla başlatılırsa kamyon dolum sahnesini tek başına göster.
        // Sahne bir ekrana bağlanınca bu blok silinir. Çalıştırma: xcrun simctl launch booted com.isaanilkoca.Yukum -truckPreview
        if ProcessInfo.processInfo.arguments.contains("-truckPreview") {
            TruckLoadPreview() // Design/TruckLoadView.swift
        } else {
            LoginView()
        }
        #else
        LoginView() // uygulamanın ilk ekranı: giriş | () = örnek üret
        #endif
    }
}

#Preview { // [SWIFT] Xcode'da sağda canlı önizleme; uygulamayı etkilemez | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    ContentView() // önizlemede gösterilecek ekran
}
