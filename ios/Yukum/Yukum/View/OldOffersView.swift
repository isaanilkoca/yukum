//
//  OldOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: Yük Veren'in karara bağladığı (kabul/red/tamamlanan) tüm teklifler = "Eski teklifler". Bitmiş olanları kaydırıp kendi listesinden silebilir.
// Kabul edilen teklifin sohbetine buradan ulaşılır (aktif iş: silinemez, sohbet açık, "İşi Bitir ve Sil" sohbetin menüsünde).
// MVVM: bu dosya yalnız GÖRÜNÜM. Liste, silme kuralı, sohbet bilgisi ViewModel/OfferListViewModels.swift → OldOffersViewModel'de.
// BAĞLANTI: View/HomeView.swift → Yük Veren'in sol üst saat ikonu bu ekranı açar | kalıp: Network/OfferRequest.swift → ShipperHistoryOffer
struct OldOffersView: View {

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    @State private var viewModel = OldOffersViewModel()

    var body: some View {

        @Bindable var viewModel = viewModel // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile bağ kurar

        VStack(spacing: 16) {
            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) }

            if viewModel.offers.isEmpty {
                Text("Henüz karar verdiğin teklif yok").foregroundColor(.secondary)
            } else {
                List(viewModel.offers) { offer in
                    VStack(alignment: .leading, spacing: 6) { // bir teklifin satırı | .leading: sola yasla

                        HStack {
                            Text(offer.listingTitle).font(.headline)
                            Spacer()
                            Text("\(Int(offer.amount))₺").bold()
                        }

                        Text("\(offer.fromCityName) / \(offer.fromDistrictName) → \(offer.toCityName) / \(offer.toDistrictName)").font(.subheadline).foregroundColor(.secondary) // rota: il / ilçe → il / ilçe
                        Text("Taşımacı: \(offer.carrierName)").font(.caption).foregroundColor(.secondary) // teklifi veren Taşımacı | carrierName: backend'in Users tablosundan okuyup gönderdiği ad
                        Text("\(offer.weightKg) kg · \(offer.pickupDate)").font(.caption).foregroundColor(.secondary) // yük ağırlığı · yükleme tarihi

                        Button("Sohbet") { viewModel.openChat(offer) }.buttonStyle(.bordered) // ViewModel'deki chat'i doldurur → ChatView açılır | Kabul edilende yazılabilir, reddedilende/tamamlananda yalnız eski mesajlar okunur/silinir | .bordered: List'te satırın her yeri düğme olmasın diye stil şart

                        // durum yazısı | switch [SWIFT]: değere göre dallanır
                        switch offer.status {
                        case "Accepted": Text("Kabul ettin").font(.subheadline).foregroundColor(.green) // aktif iş
                        case "Completed": Text("Tamamlandı").font(.subheadline).foregroundColor(.gray) // iş bitti
                        default: Text("Reddettin").font(.subheadline).foregroundColor(.red) // Rejected
                        }
                    }
                    .padding(.vertical, 4) // satırın üst/alt boşluğu
                    .swipeActions { // .swipeActions [SWIFT]: satırı sola kaydırınca çıkan düğmeler
                        if viewModel.canHide(offer) { // KURAL ViewModel'de: yalnız reddedilen ya da tamamlanan silinebilir | kabul edilen AKTİF İŞ, silinemez (API de 409 verir)
                            Button("Sil", role: .destructive) { Task { await viewModel.hide(offer) } } // role: .destructive: kırmızı silme düğmesi
                        }
                    }
                }.listStyle(.plain) // düz beyaz zemin
                .refreshable { await viewModel.load() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince iş çalışır | NE İŞE YARAR: kullanıcı güncel veriyi kendisi ister
            }
        }
        .padding() // kenarlardan boşluk
        .navigationTitle("Eski Teklifler") // [SWIFT] üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() } // .task [SWIFT]: ekran HER göründüğünde çalışır | listeyi yükler
        // .navigationDestination(item:) [SWIFT]: ViewModel'deki chat dolunca ChatView'a GEÇER, nil olunca geri döner (List satırında NavigationLink yerine bu kullanılır, satırdaki düğmeler çalışsın diye)
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) } // BAĞLANTI: View/ChatView.swift | kim yazabilir/bitirebilir kuralı ChatContext'te
    }
}

#Preview {
    OldOffersView()
}
