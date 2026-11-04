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
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Taşımacı bir ilana basınca açılan detay ekranı. İlan bilgisini gösterir + teklif formu içerir.
// MVVM: bu dosya yalnız GÖRÜNÜM. Tutar/not alanları, doğrulama, gönderme, hata Features/Listings/ListingDetailViewModel.swift'te.
// BAĞLANTI: Features/Listings/HomeView.swift → Taşımacı listesindeki NavigationLink bu ekranı açar ve ilanı verir
//           Teklif gönderimi: Features/Offers/OfferService.swift → create | paket kalıbı: Models/Offers/
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

    // ⮕ KULLANIM [body]: okur: ListingDetailViewModelTests (test)
    var body: some View { // ekranın içeriği

        @Bindable var viewModel = viewModel // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile bağ kurar (TextField doğrudan ViewModel'e yazsın diye)
        let listing = viewModel.listing // kısa ad: aşağıda sık kullanılıyor

        VStack(alignment: .leading, spacing: 16) { // alt alta dizer | .leading: sola yasla | VStack [SWIFT]: elemanları alt alta dizer
            Text(listing.title).font(.title2).bold() // ilan başlığı | .font [SWIFT]: yazı boyutu/stili | .bold [SWIFT]: yazıyı kalın yapar
            Text("\(listing.fromCityName) / \(listing.fromDistrictName) → \(listing.toCityName) / \(listing.toDistrictName)").font(.headline) // il / ilçe → il / ilçe | \( ) = yazının içine değişken koyar
            Text("Ağırlık : \(listing.weightKg) kg ")
            Text("Yükleme Tarihi : \(listing.pickupDate)") // API'den gelen "yyyy-MM-dd" yazısı

            if let budget = listing.budget { // if let: budget nil değilse içine gir | bütçe isteğe bağlıydı
                Text("Bütçe : \(Int(budget)) TL") // doluysa göster
            }

            Divider() // ince ayırıcı çizgi | Divider [SWIFT]: ince ayırıcı çizgi

            if let offer = listing.myOfferAmount { // daha önce teklif verdiyse
                Text("Mevcut Teklifin: \(Int(offer)) ₺").foregroundColor(.secondary) // Int(): 1200.0 yerine 1200 göster | .secondary [SWIFT]: gri yazı | .foregroundColor [SWIFT]: yazı rengi
            }

            // $ = iki yönlü bağ: yazılan doğrudan ViewModel'deki amountText'e gider | .numberPad: yalnız rakam klavyesi
            TextField("Teklif tutarı (₺)", text: $viewModel.amountText).textFieldStyle(.roundedBorder).keyboardType(.numberPad) // ⮕ ListingDetailViewModel.amountText | .textFieldStyle [SWIFT]: yazı kutusu stili | .keyboardType [SWIFT]: klavye türü
            TextField("Not (isteğe bağlı)", text: $viewModel.note).textFieldStyle(.roundedBorder) // not alanı

            if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // doluysa kırmızı yaz, nil ise çizilmez

            // Düğme yalnız TETİKLEYİCİ: tutarı kontrol etme, paketi hazırlama, gönderme ViewModel.submit()'te | başarıda dismiss() ile ana sayfaya döner, hatada ViewModel errorMessage'ı doldurur
            // buttonTitle: "Teklifi Gönder" ya da (daha önce teklif varsa) "Teklifi Güncelle" | KURAL ViewModel'de
            Button(viewModel.buttonTitle) { // Button [SWIFT]: dokununca kod çalıştıran düğme
                Task { // Task [SWIFT]: düğmede await kullanmamızı sağlar; ekran donmaz
                    if await viewModel.submit() { dismiss() } // başarılıysa ekranı kapat → ana sayfaya dön | ⮕ ListingDetailViewModel.submit() → OfferService.create(CreateOfferRequest) → POST /api/v1/listings/{id}/offers
                }
            }
            .buttonStyle(.borderedProminent) // dolu, renkli düğme görünümü | .buttonStyle [SWIFT]: düğme görünüm stili
            .disabled(viewModel.isLoading) // isLoading true iken basılamaz (çift tıklama olmasın) | .disabled [SWIFT]: koşul doğruysa basılamaz/kilitli

            Spacer() // kalan boşluğu doldurur, yazılar üste çıkar | Spacer [SWIFT]: kalan boşluğu doldurur
        }
        .padding() // kenarlardan boşluk | .padding [SWIFT]: etrafında boşluk bırakır
        .navigationTitle("İlan Detayı") // [SWIFT] üst çubuk başlığı | geri oku NavigationStack'ten otomatik gelir | .navigationTitle [SWIFT]: üst çubuk başlığı
        .navigationBarTitleDisplayMode(.inline) // [SWIFT]: başlığı küçük, ortada gösterir | .navigationBarTitleDisplayMode [SWIFT]: üst başlığın boyut biçimi
    }
}
