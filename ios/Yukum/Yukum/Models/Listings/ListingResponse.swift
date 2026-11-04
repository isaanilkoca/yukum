//
//  ListingResponse.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ListingResponse (ilan verme cevabı) ─────────────────────────
// │ MODEL     : İlan açılınca sunucunun döndüğü kısa özet (id, başlık)
// │ ÜRETEN    : Models/Services/ListingService.create ← Models/Networking/APIClient
// │ TÜKETEN   : ViewModels/CreateListingViewModel.submit(): yalnız başarılı olduğunu kullanır → Views/CreateListingView dismiss() ile kapanır
// └──────────────────────────────────────────────────────────────────────

// API'den dönen oluşturulmuş ilan (201). Yalnız ihtiyacımız olan alanları aldık, Swift fazlasını yok sayar.
// BAĞLANTI: Models/Services/ListingService.swift create() bu pakete çevirip geri döner → Views/CreateListingView.swift okur
// ⮕ KULLANIM [ListingResponse]: kullanır: ListingService › create(), ListingServicing › create(), FakeListingService (test)
struct ListingResponse: Decodable { // Decodable [SWIFT]: gelen JSON'dan üretilebilir
    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: String // ilan numarası (GUID yazı olarak gelir)
    // ⮕ KULLANIM [title]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let title: String
}
