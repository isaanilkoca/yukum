//
//  00_Rehber_Models_Offers.swift — Models/Offers/ — TEKLİF, İŞ, PUAN, PROFİL
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Teklifin ve teklif kabul edilince başlayan "işin" kalıpları. Aynı teklif üç farklı yerden üç farklı biçimde görülür.
//
// DOSYA → TÜR → KİM GÖRÜR → API UCU
//  CarrierOffer.swift          Taşımacının KENDİ teklifi (ilan özeti, tutar, durum, aşama, iptal talebi, shipperId?, hasMessages)
//                                Taşımacı → GET /offers/mine (Tekliflerim / Devam Eden İşler / Geçmiş)
//  ListingOffer.swift          İlana GELEN teklif (taşımacı adı/puanı, araç türü/marka/model/yıl, tahmini teslim tarihi, carrierId)
//                                Yük Veren → GET /listings/{id}/offers
//  ShipperHistoryOffer.swift   Yük Verenin karar verdiği teklifler (kabul/red geçmişi, aşama, puanlandı mı)
//                                Yük Veren → GET /offers/history (Devam Eden İşler / Eski Teklifler)
//  CreateOfferRequest.swift    {amount, note?, vehicleId?, estimatedDeliveryDate?} → POST /listings/{id}/offers
//  OfferResponse.swift         teklif cevabı (tutar)
//  UnseenCount.swift           {count} ← GET /offers/mine/unseen-count (Taşımacının görmediği kararlar → rozet)
//  JobStage.swift              iş aşaması: NotStarted → PickedUp → InTransit → Delivered; title (ekran yazısı), advanceTitle (sonraki aşama düğmesi; Teslim edildi'de nil)
//                                Taşımacı ilerletir → POST /offers/{id}/advance
//  CancelRequestInfo.swift     CancelRequestInfo (açık karşılıklı iptal talebi) · CancelRequestBody → POST /offers/{id}/cancel-request
//                              CancelApproveBody → POST …/cancel-request/approve · CancelReasons (role göre nedenler + placeholder ipuçları)
//  CreateReviewRequest.swift   {rating 1–5, comment?} → POST /offers/{id}/review (yalnız Yük Veren, iş tamamlanınca, bir kez)
//  CarrierProfile.swift        CarrierProfile (ortalama puan, yorumlar, araçlar) ← GET /carriers/{id} · CarrierReview
//                              ShipperPublicProfile ← GET /shippers/{id} (telefon/e-posta/vergi GİZLİ)
//  RatingText.swift            RatingText.summary(rating:count:) → "★ 4.6 (12)" · hiç puanı yoksa "Yeni"
//
// DURUMLAR (status): Pending → Accepted (iş başlar) / Rejected / Withdrawn ; Accepted → Completed / Cancelled (karşılıklı iptal)
// KULLANAN: Services/OfferService, ReviewService → MyOffers, OldOffers, ListingOffers, ListingDetail, Rating, *Profile ViewModel'leri
