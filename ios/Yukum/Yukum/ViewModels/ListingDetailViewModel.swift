//
//  ListingDetailViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: ListingDetailViewModel ──────────────────────────────────────
// │ EKRAN     : Views/ListingDetailView (@State private var viewModel, init(listing:)) — ilan detayı + teklif formu
// │ SERVİS    : Models/Services/Protocols/OfferServicing → OfferService.create
// │ MODEL     : Listing (gösterilen ilan), CreateOfferRequest (giden), OfferResponse (gelen)
// │ AKIŞ      : Tutar/not $viewModel ile yazılır → "Teklifi Gönder" → submit(): doğrula → CreateOfferRequest → OfferService.create → true ise View kapanır
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: ilan detay ekranındaki TEKLİF formunun durumu ve mantığı (tutar, not, doğrulama, gönderme, hata)
// BAĞLANTI: Views/ListingDetailView.swift kullanır | servis: Models/Services/OfferService.swift (OfferServicing) | paket kalıbı: Models/Offers/ → CreateOfferRequest
// ⮕ KULLANIM [ListingDetailViewModel]: kullanır: ListingDetailView › viewModel, ListingDetailView › init(), ListingDetailViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class ListingDetailViewModel {

    // ⮕ ZİNCİR: Views/ListingDetailView: başlık, rota, ağırlık, tarih, bütçe satırları | gelen: Views/HomeView Taşımacı listesi NavigationLink → ListingDetailView(listing:) | MODEL: Listing
    // ⮕ KULLANIM [listing]: okur: ListingDetailViewModel › hasExistingOffer, ListingDetailViewModel › submit()
    let listing: Listing // teklif verilen ilan
    // ⮕ KULLANIM [service]: okur: ListingDetailViewModel › submit()
    private let service: OfferServicing
    private let listingService: ListingServicing // emsal fiyat için (teklif servisinden ayrı: konu ilan)

    // ⮕ ZİNCİR: Views/ListingDetailView: TextField("Teklif tutarı", text: $viewModel.amountText) | submit() Int'e çevirip CreateOfferRequest.amount'a koyar
    // ⮕ KULLANIM [amountText]: okur: ListingDetailViewModel › submit() | bağlar(okur+yazar): ListingDetailView › body | YAZAR: ListingDetailViewModelTests (test)
    var amountText = "" // kullanıcının yazdığı tutar | TextField yazıyla çalıştığı için String, göndermeden önce Int'e çevrilir
    // ⮕ ZİNCİR: Views/ListingDetailView: TextField("Not") | CreateOfferRequest.note (boşsa nil)
    // ⮕ KULLANIM [note]: okur: ListingDetailViewModel › submit(), ListingDetailViewModelTests (test) | bağlar(okur+yazar): ListingDetailView › body | YAZAR: ListingDetailViewModelTests (test)
    var note = "" // isteğe bağlı not
    // ⮕ ZİNCİR: Views/ListingDetailView: if let errorMessage → kırmızı yazı ("Geçerli bir tutar gir." ya da sunucu mesajı)
    // ⮕ KULLANIM [errorMessage]: YAZAR: ListingDetailViewModel › submit() | okur: ListingDetailViewModelTests (test)
    var errorMessage: String?
    // ⮕ ZİNCİR: Views/ListingDetailView: "Teklifi Gönder" düğmesi .disabled(viewModel.isLoading)
    // ⮕ KULLANIM [isLoading]: YAZAR: ListingDetailViewModel › submit() | okur: ListingDetailView › body
    var isLoading = false

    // Bu sınır sunucudaki sınırla AYNI (en fazla 100.000.000 ₺): aşırı büyük değer sunucuda 400 verirdi, burada daha ekranda yakalanır
    // ⮕ KULLANIM [maxAmount]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    static let maxAmount = 100_000_000 // static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)

    // ⮕ ZİNCİR: listing.myOfferAmount dolu mu | Views/ListingDetailView "Mevcut Teklifin" satırı ve buttonTitle
    // ⮕ KULLANIM [hasExistingOffer]: okur: ListingDetailViewModel › buttonTitle
    var hasExistingOffer: Bool { listing.myOfferAmount != nil } // daha önce teklif verdiyse düğme "Güncelle" der
    // ⮕ ZİNCİR: Views/ListingDetailView: Button(viewModel.buttonTitle) — "Teklifi Gönder" ya da "Teklifi Güncelle"
    // ⮕ KULLANIM [buttonTitle]: okur: ListingDetailView › body, ListingDetailViewModelTests (test)
    var buttonTitle: String { hasExistingOffer ? "Teklifi Güncelle" : "Teklifi Gönder" }

    var isFavorite: Bool // kalbin durumu | ilk değer listeden gelir (Listing.isFavorite), sonra kullanıcı değiştirir

    init(listing: Listing, service: OfferServicing = OfferService(), listingService: ListingServicing = ListingService()) {
        self.listing = listing
        self.service = service
        self.listingService = listingService
        self.isFavorite = listing.isFavorite
    }

    // toggleFavorite: kalbe basınca | İYİMSER GÜNCELLEME (optimistic update): kalp ÖNCE hemen döner, istek arkadan gider
    // NEDEN: cevabı bekleyince kalp gecikmeli dönerdi, uygulama yavaş hissettirirdi | istek başarısız olursa eski hâline GERİ DÖNER ve hata yazılır
    // ZİNCİR: Views/ListingDetailView toolbar kalbi → bu fonksiyon → ListingService.setFavorite → PUT/DELETE /api/v1/listings/{id}/favorite
    func toggleFavorite() async {
        let target = !isFavorite // hedef durum
        isFavorite = target
        errorMessage = nil
        do { try await listingService.setFavorite(listingId: listing.id, isFavorite: target) }
        catch {
            isFavorite = !target // geri al
            if let message = error.userMessage { errorMessage = message }
        }
    }

    // recordView: ilan detayı açıldı | try? : hata olursa sessiz geç (sayaç yardımcı bilgi, ekranı bozmamalı)
    // ZİNCİR: View .task → bu fonksiyon → POST /api/v1/listings/{id}/view | sunucu aynı kişiyi günde bir kez sayar
    func recordView() async {
        try? await listingService.recordView(listingId: listing.id)
    }

    // ─── Emsal fiyat ───
    var reference: PriceReference? // dolana kadar nil; sunucu "yetersiz veri" derse medianAmount nil

    // referenceText: ekranda görünecek yazı | nil = hiçbir şey çizilmez (veri yok ya da hata)
    // ZİNCİR: Views/ListingDetailView: if let text = viewModel.referenceText { Text(text) } ← loadReference() ← GET /api/v1/price-reference
    var referenceText: String? {
        guard let median = reference?.medianAmount, let count = reference?.sampleCount else { return nil } // guard let [SWIFT]: nil ise erken çık
        return "Bu rotada emsal fiyat: \(Int(median)) ₺ (son \(count) iş)"
    }

    // loadReference: ilanın rotası için emsal fiyatı ister | ÇAĞIRAN: View .task
    // try? : hata olursa sessiz geç (emsal fiyat yardımcı bilgi, teklif vermeyi engellememeli) | ilan alanları Listing'ten gelir
    func loadReference() async {
        reference = try? await listingService.priceReference(fromCityId: listing.fromCityId, toCityId: listing.toCityId, vehicleType: listing.vehicleType)
    }

    // submit: Teklifi Gönder | -> Bool: başarılı mı (ekran başarılıysa ana sayfaya döner)
    // ⮕ ZİNCİR: Views/ListingDetailView: Button { Task { if await viewModel.submit() { dismiss() } } } | OfferService.create(listingId:_:) ← CreateOfferRequest
    // ⮕ KULLANIM [submit]: çağırır: ListingDetailView › body, ListingDetailViewModelTests (test)
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
