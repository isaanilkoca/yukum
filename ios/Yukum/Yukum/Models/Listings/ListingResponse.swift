//
//  ListingResponse.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: ListingResponse (ilan verme cevabı) ─────────────────────────
// │ MODEL     : İlan açılınca sunucunun döndüğü kısa özet (id, başlık)
// │ ÜRETEN    : Services/ListingService.create ← Networking/APIClient
// │ TÜKETEN   : ViewModels/CreateListingViewModel.submit(): yalnız başarılı olduğunu kullanır → Views/CreateListingView dismiss() ile kapanır
// └──────────────────────────────────────────────────────────────────────

// API'den dönen oluşturulmuş ilan (201). Yalnız ihtiyacımız olan alanları aldık, Swift fazlasını yok sayar.
// BAĞLANTI: Services/ListingService.swift create() bu pakete çevirip geri döner → Views/CreateListingView.swift okur
struct ListingResponse: Decodable { // Decodable [SWIFT]: gelen JSON'dan üretilebilir
    let id: String // ilan numarası (GUID yazı olarak gelir)
    let title: String
}
