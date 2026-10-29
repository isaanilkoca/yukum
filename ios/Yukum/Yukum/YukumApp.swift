//
//  YukumApp.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi: View, Text, VStack, Button hepsi burada

// BU DOSYA: uygulamanın giriş noktası. Uygulama açılınca Swift ilk buradan başlar.
// BAĞLANTI: WindowGroup → ContentView.swift'teki ContentView'ı açar → o da View/LoginView.swift'i gösterir.
@main // [SWIFT] "program buradan başlar" işareti | projede yalnız bir tane olabilir
struct YukumApp: App { // YukumApp [BİZİM] ad | App [SWIFT]: "bu struct bir uygulamadır" sözleşmesi
    var body: some Scene { // body [SWIFT] zorunlu özellik | Scene: uygulamanın pencere kısmı | some: tür Swift'e bırakıldı
        WindowGroup { // [SWIFT] ana pencere kutusu | iPhone'da tek pencere gösterir
            ContentView() // pencerede ilk açılacak ekran | () = ContentView'dan bir örnek üret
        }
    }
}
