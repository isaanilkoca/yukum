//
//  OldOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: OldOffersView (Eski Teklifler, Yük Veren) ─────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Teklif listesi           →  viewModel.offers ← load()           →  OfferService.shipperHistory()   →  GET /api/v1/offers/history       →  [ShipperHistoryOffer]
// │ Sil (kaydırınca)         →  viewModel.canHide(_:) / hide(_:)    →  OfferService.hide()             →  DELETE /api/v1/offers/{id}       →  (yok)
// │ Sohbet düğmesi           →  viewModel.openChat(_:)              →  chat = ChatContext.forShipperHistory →  (ChatView açılır)           →  ChatContext
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Yük Veren'in karara bağladığı (kabul/red/tamamlanan) tüm teklifler = "Eski teklifler". Bitmiş olanları kaydırıp kendi listesinden silebilir.
// Kabul edilen teklifin sohbetine buradan ulaşılır (aktif iş: silinemez, sohbet açık, "İşi Bitir ve Sil" sohbetin menüsünde).
// MVVM: bu dosya yalnız GÖRÜNÜM. Liste, silme kuralı, sohbet bilgisi ViewModels/OfferListViewModels.swift → OldOffersViewModel'de.
// BAĞLANTI: Views/HomeView.swift → Yük Veren'in sol üst saat ikonu bu ekranı açar | kalıp: Models/Offers/ → ShipperHistoryOffer
struct OldOffersView: View {

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    @State private var viewModel = OldOffersViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    var body: some View {

        @Bindable var viewModel = viewModel // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile bağ kurar

        VStack(spacing: 16) { // VStack [SWIFT]: elemanları alt alta dizer
            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // Text [SWIFT]: yazı gösterir | .foregroundColor [SWIFT]: yazı rengi

            if viewModel.offers.isEmpty {
                Text("Henüz karar verdiğin teklif yok").foregroundColor(.secondary)
            } else {
                List(viewModel.offers) { offer in // ⮕ OldOffersViewModel.offers ← OfferService.shipperHistory() → [ShipperHistoryOffer]
                    VStack(alignment: .leading, spacing: 6) { // bir teklifin satırı | .leading: sola yasla

                        HStack { // HStack [SWIFT]: elemanları yan yana dizer
                            Text(offer.listingTitle).font(.headline) // .font [SWIFT]: yazı boyutu/stili
                            Spacer() // Spacer [SWIFT]: kalan boşluğu doldurur
                            Text("\(Int(offer.amount))₺").bold() // .bold [SWIFT]: yazıyı kalın yapar
                        }

                        Text("\(offer.fromCityName) / \(offer.fromDistrictName) → \(offer.toCityName) / \(offer.toDistrictName)").font(.subheadline).foregroundColor(.secondary) // rota: il / ilçe → il / ilçe
                        Text("Taşımacı: \(offer.carrierName)").font(.caption).foregroundColor(.secondary) // teklifi veren Taşımacı | carrierName: backend'in Users tablosundan okuyup gönderdiği ad
                        Text("\(offer.weightKg) kg · \(offer.pickupDate)").font(.caption).foregroundColor(.secondary) // yük ağırlığı · yükleme tarihi

                        Button("Sohbet") { viewModel.openChat(offer) }.buttonStyle(.bordered) // ViewModel'deki chat'i doldurur → ChatView açılır | Kabul edilende yazılabilir, reddedilende/tamamlananda yalnız eski mesajlar okunur/silinir | .bordered: List'te satırın her yeri düğme olmasın diye stil şart | Button [SWIFT]: dokununca kod çalıştıran düğme | .buttonStyle [SWIFT]: düğme görünüm stili

                        // durum yazısı | switch [SWIFT]: değere göre dallanır
                        switch offer.status {
                        case "Accepted": Text("Kabul ettin").font(.subheadline).foregroundColor(.green) // aktif iş
                        case "Completed": Text("Tamamlandı").font(.subheadline).foregroundColor(.gray) // iş bitti
                        default: Text("Reddettin").font(.subheadline).foregroundColor(.red) // Rejected
                        }
                    }
                    .padding(.vertical, 4) // satırın üst/alt boşluğu | .padding [SWIFT]: etrafında boşluk bırakır
                    .swipeActions { // .swipeActions [SWIFT]: satırı sola kaydırınca çıkan düğmeler
                        if viewModel.canHide(offer) { // KURAL ViewModel'de: yalnız reddedilen ya da tamamlanan silinebilir | kabul edilen AKTİF İŞ, silinemez (API de 409 verir)
                            Button("Sil", role: .destructive) { Task { await viewModel.hide(offer) } } // role: .destructive: kırmızı silme düğmesi | ⮕ OldOffersViewModel.hide → OfferService.hide → DELETE /api/v1/offers/{id} | await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder) | Task [SWIFT]: arka planda çalışan iş: normal koddan await kullanabilmeyi sağlar
                        }
                    }
                }.listStyle(.plain) // düz beyaz zemin | .listStyle [SWIFT]: liste görünüm stili
                .refreshable { await viewModel.load() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince iş çalışır | NE İŞE YARAR: kullanıcı güncel veriyi kendisi ister
            }
        }
        .padding() // kenarlardan boşluk
        .navigationTitle("Eski Teklifler") // [SWIFT] üst çubuk başlığı | .navigationTitle [SWIFT]: üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline) // .navigationBarTitleDisplayMode [SWIFT]: üst başlığın boyut biçimi
        .task { await viewModel.load() } // .task [SWIFT]: ekran HER göründüğünde çalışır | listeyi yükler
        // .navigationDestination(item:) [SWIFT]: ViewModel'deki chat dolunca ChatView'a GEÇER, nil olunca geri döner (List satırında NavigationLink yerine bu kullanılır, satırdaki düğmeler çalışsın diye)
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) } // BAĞLANTI: Views/ChatView.swift | kim yazabilir/bitirebilir kuralı ChatContext'te
    }
}

#Preview { // #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    OldOffersView()
}
