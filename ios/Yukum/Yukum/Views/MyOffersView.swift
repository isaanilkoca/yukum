//
//  MyOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: MyOffersView (Tekliflerim, Taşımacı) ──────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Bekleyenler bölümü       →  viewModel.pendingOffers (offers'tan)  →  OfferService.myOffers()      →  GET /api/v1/offers/mine          →  [CarrierOffer]
// │ Geçmiş bölümü            →  viewModel.historyOffers (offers'tan)  →  (aynı çağrı)                  →  (aynı)                           →  [CarrierOffer]
// │ "Yeni" rozeti            →  CarrierOffer.isNew ← loadAndMarkSeen()  →  OfferService.markSeen()     →  POST /api/v1/offers/mine/seen    →  (yok)
// │ Sil (kaydırınca)         →  viewModel.canHide(_:) / hide(_:)    →  OfferService.hide()             →  DELETE /api/v1/offers/{id}       →  (yok)
// │ Sohbet düğmesi           →  viewModel.canChat(_:) / openChat(_:) → chat = ChatContext.forCarrier     →  (ChatView açılır)                →  ChatContext
// │ HAZIR (Swift/Apple) [SWIFT] : @State, @Bindable, @ViewBuilder, await, Task, import SwiftUI, View, List, ForEach, Section, VStack, HStack, Text, Button, Spacer, Color, Capsule, #Preview, .task, .refreshable, .navigationDestination, .navigationTitle, .swipeActions, .padding, .buttonStyle, .listStyle, .font, .foregroundColor, .background, .clipShape, Int, ViewBuilder, .bold, .navigationBarTitleDisplayMode
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: MyOffersView | fonksiyonlar: offerRow | değişken/durumlar: viewModel, body, errorMessage
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Taşımacı'nın tüm teklifleri = "Tekliflerim". İki bölüm: BEKLEYENLER (karar bekleyen) ve GEÇMİŞ (kabul/red/tamamlanan/iptal). Bitmiş olanları silebilir.
// MVVM: bu dosya yalnız GÖRÜNÜM. Liste, bölümler, silme kuralları, sohbet bilgisi ViewModels/OfferListViewModels.swift → MyOffersViewModel'de.
// BAĞLANTI: Views/HomeView.swift → Taşımacı'nın sağ üst kutu ikonu (rozetli) bu ekranı açar | kalıp: Models/Offers/ → CarrierOffer
struct MyOffersView: View { // MyOffersView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: ekranın durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar
    @State private var viewModel = MyOffersViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile bağ kurar (.navigationDestination(item: $viewModel.chat) için)
        @Bindable var viewModel = viewModel

        VStack(spacing: 16) { // VStack [SWIFT]: elemanları alt alta dizer | spacing: aralarındaki boşluk

            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: nil değilse içine gir | doluysa kırmızı yaz, nil ise hiç çizilmez | Text [SWIFT]: yazı gösterir | .foregroundColor [SWIFT]: yazı rengi

            if viewModel.offers.isEmpty { // isEmpty [SWIFT]: liste boş mu | hiç teklif verilmemişse
                Text("Henüz teklif vermedin.").foregroundColor(.secondary) // .secondary [SWIFT]: gri, ikincil yazı rengi | boş durum mesajı
            } else { // liste doluysa bölümleri çiz

                // List [SWIFT]: kaydırılabilir satır listesi | Section [SWIFT]: listeyi başlıklı bölümlere ayırır
                List {
                    if !viewModel.pendingOffers.isEmpty {
                        Section("Bekleyenler") { // karar bekleyen teklifler
                            ForEach(viewModel.pendingOffers) { offer in offerRow(offer) } // ForEach [SWIFT]: listedeki her teklif için bir satır çizer | ⮕ MyOffersViewModel.pendingOffers ← offers ← OfferService.myOffers() → [CarrierOffer]
                        }
                    }
                    if !viewModel.historyOffers.isEmpty {
                        Section("Geçmiş") { // kabul edilen, reddedilen, tamamlanan, iptal edilen teklifler
                            ForEach(viewModel.historyOffers) { offer in offerRow(offer) } // ⮕ MyOffersViewModel.historyOffers (kabul/red/tamamlanan/iptal)
                        }
                    }
                }.listStyle(.plain) // .plain: düz beyaz zemin, ince çizgiler | varsayılan gri zemin olurdu | .listStyle [SWIFT]: liste görünüm stili
                .refreshable { await viewModel.load() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince iş çalışır, yenileme çarkı iş bitince kendiliğinden kapanır | NE İŞE YARAR: kullanıcı güncel veriyi kendisi ister | await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
            }
        }
        .padding() // ekranın kenarlarından boşluk
        .navigationTitle("Tekliflerim") // [SWIFT] üst çubuk başlığı | geri oku HomeView'daki NavigationStack'ten otomatik gelir | .navigationTitle [SWIFT]: üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline) // [SWIFT]: başlığı küçük, ortada gösterir | .navigationBarTitleDisplayMode [SWIFT]: üst başlığın boyut biçimi
        .task { await viewModel.loadAndMarkSeen() } // .task [SWIFT]: ekran HER göründüğünde çalışır | ÖNCE listeyi çek ("Yeni" rozetleri çizilsin), SONRA "görüldü" yap (anasayfadaki rozet söner) | ⮕ önce OfferService.myOffers(), sonra OfferService.markSeen()
        // NEDEN .navigationDestination(item:) KULLANDIK, NavigationLink değil?
        //   NavigationLink'i List satırının İÇİNE koyarsak satırın her yeri link olur, içindeki "Sohbet" düğmesi çalışmaz.
        //   Çözüm: düğme sayfa AÇMAZ, ViewModel'deki chat değişkenini doldurur. Kural: "chat dolunca ChatView'a geç, nil olunca kapat" | ChatContext Hashable olduğu için SwiftUI seçili öğeyi takip edebilir.
        .navigationDestination(item: $viewModel.chat) { context in ChatView(context: context) } // BAĞLANTI: Views/ChatView.swift | kim yazabilir/bitirebilir kuralı ChatContext'te
    }

    // offerRow: tek bir teklifin satırı | @ViewBuilder [SWIFT]: fonksiyon birden çok görünüm döndürebilir
    // NEDEN fonksiyon: aynı satır iki bölümde (Bekleyenler, Geçmiş) tekrar kullanılıyor
    @ViewBuilder
    private func offerRow(_ offer: CarrierOffer) -> some View {
        VStack(alignment: .leading, spacing: 6) { // bir teklifin satırı: alt alta | .leading: sola yasla

            HStack { // HStack [SWIFT]: elemanları yan yana dizer | sol: ilan başlığı + rozet, sağ: tutar
                Text(offer.listingTitle).font(.headline) // teklif verdiğimiz ilanın başlığı | .headline [SWIFT]: kalın başlık yazısı | .font [SWIFT]: yazı boyutu/stili

                if offer.isNew { // isNew: API'den gelen true/false | true = Yük Veren karar verdi (kabul/red) AMA Taşımacı henüz bu ekranı açıp görmedi | "bildirim" yerine uygulama içi rozet
                    Text("Yeni").font(.caption2).bold().foregroundColor(.white) // küçük kalın beyaz yazı | .caption2 [SWIFT]: en küçük yazı boyu | .bold [SWIFT]: yazıyı kalın yapar
                        .padding(.horizontal, 6).padding(.vertical, 2) // .padding [SWIFT]: yazının etrafında boşluk | .horizontal: sağ-sol | .vertical: üst-alt
                        .background(Color.red).clipShape(Capsule()) // .background: arka plan rengi | .clipShape(Capsule()): köşeleri tam yuvarlar, hap şekli olur | Color [SWIFT]: renk | Capsule [SWIFT]: hap şekli | .background [SWIFT]: arka plan | .clipShape [SWIFT]: görünümü şekle göre keser
                }

                Spacer() // Spacer [SWIFT]: kalan boşluğu doldurur, sonraki eleman (tutar) sağa yaslanır
                Text("\(Int(offer.amount)) ₺").bold() // \( ) = yazının içine değişken koyar | Int(): 48000.0 yerine 48000 | .bold(): kalın
            }

            Text("\(offer.fromCityName) / \(offer.fromDistrictName) → \(offer.toCityName) / \(offer.toDistrictName)").font(.subheadline).foregroundColor(.secondary) // rota: il / ilçe → il / ilçe
            Text("Yük Veren: \(offer.shipperName)").font(.caption).foregroundColor(.secondary) // ilanı kimin açtığı | shipperName: backend'in Users tablosundan okuyup gönderdiği ad
            Text("\(offer.weightKg) kg · \(offer.pickupDate)").font(.caption).foregroundColor(.secondary) // yük ağırlığı · yükleme tarihi

            // durum yazısı | switch [SWIFT]: bir değere göre dallanır, çok if/else yerine okunaklı | offer.status API'den yazı gelir
            switch offer.status {
            case "Accepted": Text("Kabul edildi").foregroundColor(.green) // case: değer buna eşitse | Yük Veren kabul etti
            case "Rejected": Text("Reddedildi").foregroundColor(.red) // Yük Veren reddetti
            case "Cancelled": Text("İlan kaldırıldı").foregroundColor(.gray) // ilan sahibi ilanı yayından kaldırdı / işi iptal etti | sohbet kilitli, silinebilir
            case "Completed": Text("Tamamlandı").foregroundColor(.gray) // iş bitti, anlaşma tamam | silinebilir
            default: Text("Beklemede").foregroundColor(.orange) // default: yukarıdakilerin hiçbiri değilse (Pending) | switch'te zorunlu
            }

            if viewModel.canChat(offer) { // KURAL ViewModel'de: reddedilen teklifte sohbet yok
                Button("Sohbet") { viewModel.openChat(offer) }.buttonStyle(.bordered) // ViewModel'deki chat'i doldurur → ChatView açılır | .bordered: List'te satırın her yeri düğme olmasın diye stil şart | ⮕ MyOffersViewModel.openChat → ChatContext.forCarrier → .navigationDestination → ChatView | Button [SWIFT]: dokununca kod çalıştıran düğme | .buttonStyle [SWIFT]: düğme görünüm stili
            }
        }
        .padding(.vertical, 4) // satırın üst/alt boşluğu
        // .swipeActions [SWIFT]: satırı sola kaydırınca çıkan düğmeler
        .swipeActions {
            if viewModel.canHide(offer) { // KURAL ViewModel'de: yalnız BİTMİŞ teklif silinebilir (reddedilen, tamamlanan, iptal) | bekleyen: karar yok | kabul edilen: AKTİF İŞ (API de 409 verir)
                Button("Sil", role: .destructive) { Task { await viewModel.hide(offer) } } // role: .destructive [SWIFT]: kırmızı "tehlikeli işlem" düğmesi | ⮕ MyOffersViewModel.hide → OfferService.hide → DELETE /api/v1/offers/{id} | Task [SWIFT]: arka planda çalışan iş: normal koddan await kullanabilmeyi sağlar
            }
        }
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    MyOffersView()
}
