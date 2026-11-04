//
//  ListingOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: Yük Veren kendi ilanına basınca açılır. İlana gelen BEKLEYEN teklifleri listeler (Kabul Et / Reddet / Sohbet) ve ilanı yayından kaldırma düğmesi vardır.
// Karar verilen teklifler buradan kalkıp "Eski Teklifler"e gider.
// MVVM: bu dosya yalnız GÖRÜNÜM. Teklif listesi, karar, ilanı kaldırma ViewModel/OfferListViewModels.swift → ListingOffersViewModel'de.
// BAĞLANTI: View/HomeView.swift → Yük Veren listesindeki NavigationLink bu ekranı açar ve ilanı verir | kalıp: Network/OfferRequest.swift → ListingOffer
struct ListingOffersView: View {

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    @State private var viewModel: ListingOffersViewModel

    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer | dismiss: "bu ekranı kapat" komutu | ilan kaldırılınca bu ekrandan geri dönmek için
    // showCancelConfirm: "İlanı yayından kaldır" onay penceresi açık mı | yalnız GÖRÜNÜM bilgisi
    // NEDEN onay penceresi: işlem geri alınamaz ve bekleyen tekliflerin hepsini iptal eder, yanlışlıkla basılmasın
    @State private var showCancelConfirm = false

    // init: ilan dışarıdan verilir (HomeView'daki satır), ViewModel burada oluşturulur
    init(listing: Listing) {
        _viewModel = State(initialValue: ListingOffersViewModel(listing: listing))
    }

    var body: some View {

        @Bindable var viewModel = viewModel // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile bağ kurar

        VStack(spacing: 16) {
            Text(viewModel.listing.title).font(.title3).bold() // hangi ilan olduğu

            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // doluysa kırmızı yaz, nil ise çizilmez
            if viewModel.offers.isEmpty { // liste boş mu
                Text("Henüz teklif gelmedi.").foregroundColor(.secondary) // .secondary [SWIFT]: gri yazı
            } else {
                List(viewModel.offers) { offer in // List [SWIFT]: kaydırılabilir satır listesi | offer: o anki teklif
                    VStack(alignment: .leading, spacing: 8) { // bir teklifin satırı: alt alta, sola yaslı
                        HStack {
                            Text(offer.carrierName).font(.headline) // teklifi veren taşımacı
                            Spacer()
                            Text("\(Int(offer.amount))₺").bold() // Int(): 48000.0 yerine 48000
                        }

                        if let note = offer.note {
                            Text(note).font(.caption).foregroundColor(.secondary) // küçük gri not
                        }

                        // Bu ekranda yalnız BEKLEYEN teklifler var (sunucu yalnız onları gönderir); kabul/red verilenler "Eski Teklifler"e gider
                        HStack {
                            // .borderedProminent / .bordered: ZORUNLU, yoksa List'te satırın her yeri düğme olur | .tint [SWIFT]: dolgu rengi
                            Button("Reddet") { Task { await viewModel.decide(offer, accept: false) } }.buttonStyle(.borderedProminent).tint(.red) // kırmızı dolu
                            Button("Kabul et") { Task { await viewModel.decide(offer, accept: true) } }.buttonStyle(.borderedProminent).tint(.green) // yeşil dolu
                            Button("Sohbet") { viewModel.openChat(offer) }.buttonStyle(.bordered) // ViewModel'deki chat'i doldurur → aşağıdaki .navigationDestination ChatView'ı açar | çerçeveli düğme
                        }
                    }
                    .padding(.vertical, 4)
                }.listStyle(.plain)
                .refreshable { await viewModel.load() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince iş çalışır | NE İŞE YARAR: kullanıcı güncel veriyi kendisi ister
            }
        }
        .padding()
        .navigationTitle("Gelen Teklifler") // üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline)
        // .toolbar [SWIFT]: üst çubuğa eleman koyar | sağ üstte "Kaldır": iptal olan, vazgeçilen, yanlış açılan ilanlar için
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { // sağ üst köşe
                Button("Kaldır", role: .destructive) { showCancelConfirm = true } // role: .destructive: kırmızı | basınca onay penceresi açılır
            }
        }
        // .alert [SWIFT]: ekranın ortasında çıkan uyarı penceresi | isPresented: $showCancelConfirm → true olunca açılır
        .alert("İlan yayından kaldırılsın mı?", isPresented: $showCancelConfirm) {
            Button("Yayından Kaldır", role: .destructive) { // seçilince ViewModel ilanı kaldırır; başarılıysa ilan listemizde olmadığı için geri dönülür
                Task { if await viewModel.cancelListing() { dismiss() } } // önceki ekran (HomeView) görününce .task ile listeyi kendisi yeniler
            }
            Button("Vazgeç", role: .cancel) { } // pencereyi kapatır, hiçbir şey yapmaz
        } message: {
            Text("İlan herkesin listesinden kalkar. Gelen teklifler iptal edilir, Taşımacılar bilgilendirilir ve sohbetler kapanır.")
        }
        .task { await viewModel.load() } // .task [SWIFT]: ekran HER göründüğünde çalışır | teklifleri yükler
        // NEDEN .navigationDestination(item:) KULLANDIK, NavigationLink değil? List satırının içindeki NavigationLink, satırdaki Reddet/Kabul/Sohbet düğmelerini bozar (hepsi sayfaya götürür).
        // Çözüm: düğme sayfa AÇMAZ, ViewModel'deki chat'i doldurur. Kural: "chat dolunca ChatView'a geç, nil olunca kapat"
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) } // BAĞLANTI: View/ChatView.swift | kim yazabilir/bitirebilir kuralı ChatContext'te
    }
}
