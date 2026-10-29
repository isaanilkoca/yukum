//
//  ContentView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU DOSYA: uygulamanın ilk ekran kapısı. Şimdilik sadece LoginView'a yönlendirir.
// BAĞLANTI: YukumApp.swift bu ekranı açar → burası View/LoginView.swift'i gösterir.
struct ContentView: View { // ContentView [BİZİM] ad | View [SWIFT]: "bu struct bir ekrandır" sözleşmesi
    var body: some View { // body [SWIFT] zorunlu: ekranın içeriği | some View: "bir ekran parçası döner"
        LoginView() // uygulamanın ilk ekranı: giriş | () = örnek üret
    }
}

#Preview { // [SWIFT] Xcode'da sağda canlı önizleme; uygulamayı etkilemez
    ContentView() // önizlemede gösterilecek ekran
}
