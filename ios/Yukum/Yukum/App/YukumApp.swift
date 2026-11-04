//
//  YukumApp.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 25.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi: View, Text, VStack, Button hepsi burada | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ╔══════════════════════════════════════════════════════════════════════════════════════════╗
// ║  PROJE HARİTASI — buradan başla: bir ekrandaki satırdan Model'e kadar nasıl iz sürülür      ║
// ╚══════════════════════════════════════════════════════════════════════════════════════════╝
//
// KATMANLAR (yukarıdan aşağıya her ok "şunu çağırır / şuna bağlıdır" demek)
//
//   Views/        GÖRÜNÜM       ekranı çizer, kullanıcı dokunuşunu alır        (mantık YOK)
//      ↓  viewModel.x okur, viewModel.f() çağırır
//   ViewModels/   DURUM + MANTIK  ekranın değişkenleri, kurallar, hata yazısı  (çizim YOK)
//      ↓  servis.f() çağırır (somut sınıfa değil Services/Protocols/ sözleşmesine bağlı)
//   Services/     VERİ ERİŞİMİ  "hangi adres, hangi paket, ne döner"           (tek satırlık fonksiyonlar)
//      ↓  api.send(...) çağırır
//   Networking/   AĞ             jeton ekleme, 401'de yenileme, hata çevirme, JSON ↔ Model
//      ↓  URLSession → sunucu (backend API) → JSON
//   Models/       VERİ KALIPLARI  JSON'un struct hâli: Listing, CarrierOffer, ChatMessage...
//
//   Yan klasörler: Security/ (Keychain, cihaz kimliği) · Location/ (telefonun konumu) · App/ (bu dosya)
//
// NASIL İZ SÜRÜLÜR? (örnek: Eski Teklifler ekranında "Sil" düğmesi)
//   1) Views/OldOffersView.swift         → Button("Sil") { Task { await viewModel.hide(offer) } }
//   2) ViewModels/OldOffersViewModel.swift → func hide(_:) → service.hide(offerId:) çağırır, sonra load()
//   3) Services/OfferService.swift       → func hide(offerId:) → api.sendNoContent(.delete, "/api/v1/offers/{id}")
//   4) Networking/APIClient.swift        → perform → execute: jetonu ekler, URLSession ile gönderir, hata olursa APIError
//   5) Models/Offers/ShipperHistoryOffer.swift → load() ile dönen liste bu kalıptadır, ekranda List'e girer
//   Her dosyanın başındaki "BAĞLANTI HARİTASI" kutusu o dosyanın kimi çağırdığını ve kimin onu çağırdığını yazar;
//   ViewModel'deki her değişkenin ve servisteki her fonksiyonun üstünde "⮕ ZİNCİR:" satırı bir sonraki halkayı gösterir.
//
// VERİ NEREDEN GELİR, NEREYE GİDER? (okuma yönü: ekrana doğru)
//   Sunucu JSON → APIClient çevirir (Model) → Service geri verir → ViewModel değişkene yazar (@Observable) → View yeniden çizer
//
// EKRANLAR ARASI GEÇİŞ AĞACI
//   ContentView → LoginView ─┬─ "Kayıt ol" → RoleSelectionView → RegisterView | CarrierRegisterView
//                            └─ giriş başarılı (loggedInUser) → HomeView(user:)
//   HomeView · Yük Veren: satır → ListingOffersView → (Sohbet) ChatView | sol üst → OldOffersView → (Sohbet) ChatView | sağ üst + → CreateListingView
//   HomeView · Taşımacı : satır → ListingDetailView (teklif formu) | sağ üst kutu → MyOffersView → (Sohbet) ChatView
//
// ETİKET SÖZLÜĞÜ (yorumlarda tekrar eden kısaltmalar)
//   [SWIFT]  Swift/Apple'ın hazır kodu     [BİZİM]  adını bizim koyduğumuz şey
//   ⮕ ZİNCİR: bu satırdan bir sonraki halka | BAĞLANTI: dosya/sınıf bağı | ÇAĞIRAN: kim çağırır | MODEL: hangi veri kalıbı
//   $viewModel.x  ekranla ViewModel arasında İKİ YÖNLÜ bağ (yazılan ViewModel'e gider)  |  Task { await ... }  düğmede bekleyen iş
//
// BU DOSYA: uygulamanın giriş noktası. Uygulama açılınca Swift ilk buradan başlar.
// BAĞLANTI: WindowGroup → ContentView.swift'teki ContentView'ı açar → o da Views/LoginView.swift'i gösterir.
// ⮕ KULLANIM [YukumApp]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
@main // [SWIFT] "program buradan başlar" işareti | projede yalnız bir tane olabilir | @main [SWIFT]: program buradan başlar işareti
struct YukumApp: App { // YukumApp [BİZİM] ad | App [SWIFT]: "bu struct bir uygulamadır" sözleşmesi
    // ⮕ KULLANIM [body]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    var body: some Scene { // body [SWIFT] zorunlu özellik | Scene: uygulamanın pencere kısmı | some: tür Swift'e bırakıldı
        WindowGroup { // [SWIFT] ana pencere kutusu | iPhone'da tek pencere gösterir | WindowGroup [SWIFT]: ana pencereyi tanımlar
            ContentView() // pencerede ilk açılacak ekran | () = ContentView'dan bir örnek üret
        }
    }
}
