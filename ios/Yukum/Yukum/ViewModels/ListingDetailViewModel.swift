//
//  ListingDetailViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: ListingDetailViewModel ──────────────────────────────────────
// │ EKRAN     : Views/ListingDetailView (@State private var viewModel, init(listing:)) — ilan detayı + teklif formu
// │ SERVİS    : Services/Protocols/OfferServicing → OfferService.create
// │ MODEL     : Listing (gösterilen ilan), CreateOfferRequest (giden), OfferResponse (gelen)
// │ AKIŞ      : Tutar/not $viewModel ile yazılır → "Teklifi Gönder" → submit(): doğrula → CreateOfferRequest → OfferService.create → true ise View kapanır
// │ HAZIR (Swift/Apple) [SWIFT] : @Observable, async, await, defer, guard, static, String, Int, Bool, Self, Observation
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: ListingDetailViewModel | fonksiyonlar: submit | değişken/durumlar: listing, service, amountText, note, errorMessage, isLoading, maxAmount, hasExistingOffer, buttonTitle, amount …
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: ilan detay ekranındaki TEKLİF formunun durumu ve mantığı (tutar, not, doğrulama, gönderme, hata)
// BAĞLANTI: Views/ListingDetailView.swift kullanır | servis: Services/OfferService.swift (OfferServicing) | paket kalıbı: Models/Offers/ → CreateOfferRequest
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class ListingDetailViewModel {

    // ⮕ ZİNCİR: Views/ListingDetailView: başlık, rota, ağırlık, tarih, bütçe satırları | gelen: Views/HomeView Taşımacı listesi NavigationLink → ListingDetailView(listing:) | MODEL: Listing
    let listing: Listing // teklif verilen ilan
    private let service: OfferServicing

    // ⮕ ZİNCİR: Views/ListingDetailView: TextField("Teklif tutarı", text: $viewModel.amountText) | submit() Int'e çevirip CreateOfferRequest.amount'a koyar
    var amountText = "" // kullanıcının yazdığı tutar | TextField yazıyla çalıştığı için String, göndermeden önce Int'e çevrilir
    // ⮕ ZİNCİR: Views/ListingDetailView: TextField("Not") | CreateOfferRequest.note (boşsa nil)
    var note = "" // isteğe bağlı not
    // ⮕ ZİNCİR: Views/ListingDetailView: if let errorMessage → kırmızı yazı ("Geçerli bir tutar gir." ya da sunucu mesajı)
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/ListingDetailView: "Teklifi Gönder" düğmesi .disabled(viewModel.isLoading)
    var isLoading = false

    // Bu sınır sunucudaki sınırla AYNI (en fazla 100.000.000 ₺): aşırı büyük değer sunucuda 400 verirdi, burada daha ekranda yakalanır
    static let maxAmount = 100_000_000 // static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)

    // ⮕ ZİNCİR: listing.myOfferAmount dolu mu | Views/ListingDetailView "Mevcut Teklifin" satırı ve buttonTitle
    var hasExistingOffer: Bool { listing.myOfferAmount != nil } // daha önce teklif verdiyse düğme "Güncelle" der
    // ⮕ ZİNCİR: Views/ListingDetailView: Button(viewModel.buttonTitle) — "Teklifi Gönder" ya da "Teklifi Güncelle"
    var buttonTitle: String { hasExistingOffer ? "Teklifi Güncelle" : "Teklifi Gönder" }

    init(listing: Listing, service: OfferServicing = OfferService()) {
        self.listing = listing
        self.service = service
    }

    // submit: Teklifi Gönder | -> Bool: başarılı mı (ekran başarılıysa ana sayfaya döner)
    // ⮕ ZİNCİR: Views/ListingDetailView: Button { Task { if await viewModel.submit() { dismiss() } } } | OfferService.create(listingId:_:) ← CreateOfferRequest
    func submit() async -> Bool { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        // 1) Kontrol: Int(amountText) yazıyı sayıya çevirir, çeviremezse nil
        guard let amount = Int(amountText.trimmingCharacters(in: .whitespaces)), amount > 0 else { // guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
            errorMessage = "Geçerli bir tutar gir."
            return false
        }
        guard amount <= Self.maxAmount else {
            errorMessage = "Teklif tutarı en fazla 100.000.000 ₺ olabilir."
            return false
        }
        // 2) Paketi hazırla | not boşsa nil gönder (JSON'a hiç yazılmaz), doluysa baş/son boşluğu temizlenmiş yazı
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = CreateOfferRequest(amount: amount, note: trimmedNote.isEmpty ? nil : trimmedNote)

        isLoading = true // düğme kilitlenir
        errorMessage = nil
        defer { isLoading = false } // defer [SWIFT]: fonksiyondan çıkarken çalışacak kod
        // 3) Gönder
        do {
            _ = try await service.create(listingId: listing.id, body) // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
            return true
        } catch {
            if let message = error.userMessage { errorMessage = message } // örn. "Bu ilan artık teklif almıyor."
            return false
        }
    }
}
