//
//  ListingDetail.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ListingDetailView (ilan detayı + teklif formu) ────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ İlan bilgileri           →  viewModel.listing                   →  (HomeView listesinden gelir)    →  -                                →  Listing
// │ Tutar + Not kutuları     →  viewModel.amountText, note ($ bağ)  →  (submit() okur)                 →  -                                →  CreateOfferRequest
// │ Teklifi Gönder/Güncelle  →  viewModel.submit(), buttonTitle     →  OfferService.create()           →  POST /api/v1/listings/{id}/offers →  CreateOfferRequest → OfferResponse
// │ Görünüm                  →  RouteCard (Views/ListingRow), FormCard/LabeledInput (Design/FormStyle), lastik izi (Design/ActionFeedback)
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Taşımacı bir ilana basınca açılan detay ekranı. İlan bilgisini gösterir + teklif formu içerir.
// MVVM: bu dosya yalnız GÖRÜNÜM. Tutar/not alanları, doğrulama, gönderme, hata ViewModels/ListingDetailViewModel.swift'te.
// BAĞLANTI: Views/HomeView.swift → Taşımacı listesindeki NavigationLink bu ekranı açar ve ilanı verir
//           Teklif gönderimi: Models/Services/OfferService.swift → create | paket kalıbı: Models/Offers/
// ⮕ KULLANIM [ListingDetailView]: kullanır: HomeView › body
struct ListingDetailView: View { // ListingDetailView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: teklif formunun durumu ve mantığı (ilan da içinde: viewModel.listing) | @State: ekran yenilense de AYNI nesne yaşar
    // ⮕ KULLANIM [dismiss]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    // ⮕ KULLANIM [viewModel]: okur: ListingDetailView › body | bağlar(okur+yazar): ListingDetailView › body
    @State private var viewModel: ListingDetailViewModel // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir
    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer al | dismiss: "bu ekranı kapat" komutu | teklif gidince ana sayfaya dönmek için

    // init: ilan dışarıdan verilir (HomeView'daki satır), ViewModel burada oluşturulur | kalıbı: Models/Listings/ → Listing
    init(listing: Listing) {
        _viewModel = State(initialValue: ListingDetailViewModel(listing: listing))
    }

    @Environment(\.colorScheme) private var colorScheme // [SWIFT] açık/koyu mod → Palette
    @State private var feedback: ActionFeedback? // işlem sonrası lastik izi animasyonu ⮕ Design/ActionFeedback.swift

    // GÖRÜNÜM (15 Kasım, L tasarım): Taşımacı ana ekranıyla aynı dil — zemin ScreenBackground, üstte RouteCard (rota),
    //   teklif formu FormCard + LabeledInput, turuncu AccentButtonLabel. İŞLEV DEĞİŞMEDİ: aynı ViewModel alanları ve çağrıları.
    // İŞLEM SONRASI: teklif gidince / favori değişince lastik izi geçer (Taşımacı işareti); teklifte iz bitince ekran kapanır.
    // ⮕ KULLANIM [body]: okur: ListingDetailViewModelTests (test)
    var body: some View { // ekranın içeriği

        @Bindable var viewModel = viewModel // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile bağ kurar (TextField doğrudan ViewModel'e yazsın diye)
        let listing = viewModel.listing // kısa ad: aşağıda sık kullanılıyor
        let palette = Palette(isDark: colorScheme == .dark) // ⮕ Design/DesignPalette.swift

        ScrollView { // ScrollView [SWIFT]: klavye açılınca da form kaydırılabilsin
            VStack(alignment: .leading, spacing: 16) {

                RouteCard(listing: listing, showsChevron: false, favorite: viewModel.isFavorite) // ⮕ Views/ListingRow.swift › RouteCard: başlık, rota, kg/tarih, bütçe, mevcut teklif

                if let text = viewModel.referenceText { // emsal fiyat (en az 3 tamamlanmış iş yoksa çizilmez) | ⮕ ListingDetailViewModel.referenceText ← loadReference()
                    Label(text, systemImage: "chart.bar.fill")
                        .font(.subheadline).foregroundStyle(palette.title)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.accent.opacity(0.14), in: .rect(cornerRadius: 12))
                }

                // TEKLİF FORMU | $ = iki yönlü bağ: yazılan doğrudan ViewModel'e gider
                Text(viewModel.hasExistingOffer ? "Teklifini güncelle" : "Teklif ver").font(.subheadline.weight(.bold)).foregroundStyle(palette.title).padding(.leading, 4)
                FormCard { // ⮕ Design/FormStyle.swift
                    LabeledInput(label: "Teklif tutarı (₺)", systemImage: "turkishlirasign.circle.fill") {
                        TextField("ör. 25000", text: $viewModel.amountText).keyboardType(.numberPad) // ⮕ ListingDetailViewModel.amountText | .numberPad: yalnız rakam klavyesi
                    }
                    LabeledInput(label: "Not (isteğe bağlı)", systemImage: "text.bubble.fill") {
                        TextField("Yük Veren'e kısa not", text: $viewModel.note) // ⮕ ListingDetailViewModel.note
                    }
                }

                if let errorMessage = viewModel.errorMessage { FormMessage(text: errorMessage, isError: true) } // ⮕ Design/FormStyle.swift

                // Düğme yalnız TETİKLEYİCİ: kontrol, paket, gönderme ViewModel.submit()'te | buttonTitle: "Teklifi Gönder" / "Teklifi Güncelle" (kural ViewModel'de)
                // BAŞARIDA: lastik izi geçer → bitince dismiss() (ana sayfaya dön) | hatada errorMessage dolar, iz çıkmaz
                Button {
                    Task {
                        if await viewModel.submit() { // ⮕ ListingDetailViewModel.submit() → OfferService.create(CreateOfferRequest) → POST /api/v1/listings/{id}/offers
                            feedback = ActionFeedback(.track, viewModel.hasExistingOffer ? "Teklif güncellendi" : "Teklif yola çıktı") { dismiss() }
                        }
                    }
                } label: {
                    AccentButtonLabel(title: viewModel.buttonTitle) // ⮕ Design/FormStyle.swift
                }
                .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .scrollDismissesKeyboard(.interactively) // [SWIFT] kaydırınca klavye kapanır
        .background { ScreenBackground() } // ⮕ Design/ActionFeedback.swift › ScreenBackground (renk geçişi + haleler)
        .tint(palette.accent) // [SWIFT] geri oku ve imleç turuncu
        .toolbar { // üst çubuğa kalp düğmesi
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await viewModel.toggleFavorite() // ⮕ ListingDetailViewModel.toggleFavorite (iyimser güncelleme, hatada geri alır + errorMessage)
                        if viewModel.errorMessage == nil { // yalnız BAŞARIDA iz geçer
                            feedback = ActionFeedback(viewModel.isFavorite ? .track : .unload, viewModel.isFavorite ? "Favorilere eklendi" : "Favorilerden çıkarıldı") // çıkarma: boşaltma
                        }
                    }
                } label: {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart").foregroundStyle(palette.accent) // SF Symbols: dolu/boş kalp | ⮕ ListingDetailViewModel.isFavorite
                }
            }
        }
        .task { await viewModel.recordView(); await viewModel.loadReference() } // .task [SWIFT]: ekran göründüğünde çalışır | görüntülenme + emsal fiyat (hata olursa sessiz)
        .navigationTitle("İlan Detayı") // [SWIFT] üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline) // [SWIFT] başlık küçük, ortada
        .actionFeedback($feedback) // ⮕ Design/ActionFeedback.swift: feedback dolunca animasyon oynar, bitince then (dismiss) çalışır
    }
}
