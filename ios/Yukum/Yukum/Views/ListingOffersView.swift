//
//  ListingOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ListingOffersView (Gelen Teklifler, Yük Veren) ────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ İlan başlığı             →  viewModel.listing                   →  (HomeView'dan gelir)            →  -                                →  Listing
// │ Bekleyen teklif listesi  →  viewModel.offers ← load()           →  OfferService.listingOffers()    →  GET /api/v1/listings/{id}/offers →  [ListingOffer]
// │ Kabul et / Reddet        →  viewModel.decide(_:accept:)         →  OfferService.decide()           →  POST /api/v1/offers/{id}/accept|reject →  (yok)
// │ Sohbet düğmesi           →  viewModel.openChat(_:)              →  chat = ChatContext.forShipperPending →  (ChatView açılır)           →  ChatContext
// │ Kaldır (ilanı yayından)  →  viewModel.cancelListing()           →  ListingService.cancel()         →  POST /api/v1/listings/{id}/cancel →  (yok)
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Yük Veren kendi ilanına basınca açılır. İlana gelen BEKLEYEN teklifleri listeler (Kabul Et / Reddet / Sohbet) ve ilanı yayından kaldırma düğmesi vardır.
// Karar verilen teklifler buradan kalkıp "Eski Teklifler"e gider.
// MVVM: bu dosya yalnız GÖRÜNÜM. Teklif listesi, karar, ilanı kaldırma ViewModels/OfferListViewModels.swift → ListingOffersViewModel'de.
// BAĞLANTI: Views/HomeView.swift → Yük Veren listesindeki NavigationLink bu ekranı açar ve ilanı verir | kalıp: Models/Offers/ → ListingOffer
// ⮕ KULLANIM [ListingOffersView]: kullanır: HomeView › body
struct ListingOffersView: View {

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    // ⮕ KULLANIM [viewModel]: okur: ListingOffersView › body | bağlar(okur+yazar): ListingOffersView › body
    @State private var viewModel: ListingOffersViewModel // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    // ⮕ KULLANIM [dismiss]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer | dismiss: "bu ekranı kapat" komutu | ilan kaldırılınca bu ekrandan geri dönmek için
    // showCancelConfirm: "İlanı yayından kaldır" onay penceresi açık mı | yalnız GÖRÜNÜM bilgisi
    // NEDEN onay penceresi: işlem geri alınamaz ve bekleyen tekliflerin hepsini iptal eder, yanlışlıkla basılmasın
    // ⮕ KULLANIM [showCancelConfirm]: YAZAR: ListingOffersView › body | bağlar(okur+yazar): ListingOffersView › body
    @State private var showCancelConfirm = false

    // init: ilan dışarıdan verilir (HomeView'daki satır), ViewModel burada oluşturulur
    init(listing: Listing) {
        _viewModel = State(initialValue: ListingOffersViewModel(listing: listing))
    }

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {

        @Bindable var viewModel = viewModel // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile bağ kurar

        VStack(spacing: 16) { // VStack [SWIFT]: elemanları alt alta dizer
            Text(viewModel.listing.title).font(.title3).bold() // hangi ilan olduğu | Text [SWIFT]: yazı gösterir | .font [SWIFT]: yazı boyutu/stili | .bold [SWIFT]: yazıyı kalın yapar

            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // doluysa kırmızı yaz, nil ise çizilmez | .foregroundColor [SWIFT]: yazı rengi
            if viewModel.offers.isEmpty { // liste boş mu
                Text("Henüz teklif gelmedi.").foregroundColor(.secondary) // .secondary [SWIFT]: gri yazı
            } else {
                List(viewModel.offers) { offer in // List [SWIFT]: kaydırılabilir satır listesi | offer: o anki teklif | ⮕ ListingOffersViewModel.offers ← OfferService.listingOffers() → [ListingOffer]
                    VStack(alignment: .leading, spacing: 8) { // bir teklifin satırı: alt alta, sola yaslı
                        HStack { // HStack [SWIFT]: elemanları yan yana dizer
                            Text(offer.carrierName).font(.headline) // teklifi veren taşımacı
                            Spacer() // Spacer [SWIFT]: kalan boşluğu doldurur
                            Text("\(Int(offer.amount))₺").bold() // Int(): 48000.0 yerine 48000
                        }

                        if let note = offer.note {
                            Text(note).font(.caption).foregroundColor(.secondary) // küçük gri not
                        }

                        // Bu ekranda yalnız BEKLEYEN teklifler var (sunucu yalnız onları gönderir); kabul/red verilenler "Eski Teklifler"e gider
                        HStack {
                            // .borderedProminent / .bordered: ZORUNLU, yoksa List'te satırın her yeri düğme olur | .tint [SWIFT]: dolgu rengi
                            Button("Reddet") { Task { await viewModel.decide(offer, accept: false) } }.buttonStyle(.borderedProminent).tint(.red) // kırmızı dolu | ⮕ ListingOffersViewModel.decide(accept: false) → OfferService.decide → POST .../reject | await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder) | Task [SWIFT]: arka planda çalışan iş: normal koddan await kullanabilmeyi sağlar | Button [SWIFT]: dokununca kod çalıştıran düğme | .buttonStyle [SWIFT]: düğme görünüm stili
                            Button("Kabul et") { Task { await viewModel.decide(offer, accept: true) } }.buttonStyle(.borderedProminent).tint(.green) // yeşil dolu | ⮕ ListingOffersViewModel.decide(accept: true) → OfferService.decide → POST .../accept
                            Button("Sohbet") { viewModel.openChat(offer) }.buttonStyle(.bordered) // ViewModel'deki chat'i doldurur → aşağıdaki .navigationDestination ChatView'ı açar | çerçeveli düğme
                        }
                    }
                    .padding(.vertical, 4) // .padding [SWIFT]: etrafında boşluk bırakır
                }.listStyle(.plain) // .listStyle [SWIFT]: liste görünüm stili
                .refreshable { await viewModel.load() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince iş çalışır | NE İŞE YARAR: kullanıcı güncel veriyi kendisi ister
            }
        }
        .padding()
        .navigationTitle("Gelen Teklifler") // üst çubuk başlığı | .navigationTitle [SWIFT]: üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline) // .navigationBarTitleDisplayMode [SWIFT]: üst başlığın boyut biçimi
        // .toolbar [SWIFT]: üst çubuğa eleman koyar | sağ üstte "Kaldır": iptal olan, vazgeçilen, yanlış açılan ilanlar için
        .toolbar {
            
            ToolbarItem(placement: .topBarTrailing) {
                           // NavigationLink [SWIFT]: basınca süslü parantezdeki ekrana geçer | CreateListingView: Views/CreateListingView.swift (düzenleme modu)
                           // viewModel.listing: bu ekrana verilen ilan (Listing, Models/Listings) → form onunla dolar
                           // onSaved: { dismiss() }: kayıt sonrası bu ekran da kapanır, HomeView görününce .task listeyi yeniler (yeni başlık orada görünür)
                           NavigationLink("Düzenle") { CreateListingView(listing: viewModel.listing, onSaved: { dismiss() }) }
                       }
            ToolbarItem(placement: .topBarTrailing) { // sağ üst köşe | ToolbarItem [SWIFT]: üst çubukta bir eleman
                Button("Kaldır", role: .destructive) { showCancelConfirm = true } // role: .destructive: kırmızı | basınca onay penceresi açılır
            }
        }
        // .alert [SWIFT]: ekranın ortasında çıkan uyarı penceresi | isPresented: $showCancelConfirm → true olunca açılır
        .alert("İlan yayından kaldırılsın mı?", isPresented: $showCancelConfirm) {
            Button("Yayından Kaldır", role: .destructive) { // seçilince ViewModel ilanı kaldırır; başarılıysa ilan listemizde olmadığı için geri dönülür
                Task { if await viewModel.cancelListing() { dismiss() } } // önceki ekran (HomeView) görününce .task ile listeyi kendisi yeniler | ⮕ ListingOffersViewModel.cancelListing() → ListingService.cancel → POST /api/v1/listings/{id}/cancel
            }
            Button("Vazgeç", role: .cancel) { } // pencereyi kapatır, hiçbir şey yapmaz
        } message: {
            Text("İlan herkesin listesinden kalkar. Gelen teklifler iptal edilir, Taşımacılar bilgilendirilir ve sohbetler kapanır.")
        }
        .task { await viewModel.load() } // .task [SWIFT]: ekran HER göründüğünde çalışır | teklifleri yükler
        // NEDEN .navigationDestination(item:) KULLANDIK, NavigationLink değil? List satırının içindeki NavigationLink, satırdaki Reddet/Kabul/Sohbet düğmelerini bozar (hepsi sayfaya götürür).
        // Çözüm: düğme sayfa AÇMAZ, ViewModel'deki chat'i doldurur. Kural: "chat dolunca ChatView'a geç, nil olunca kapat"
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) } // BAĞLANTI: Views/ChatView.swift | kim yazabilir/bitirebilir kuralı ChatContext'te | .navigationDestination [SWIFT]: bir değer dolunca ekrana geçer
    }
}
