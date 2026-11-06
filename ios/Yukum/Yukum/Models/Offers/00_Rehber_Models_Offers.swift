//
//  00_Rehber_Models_Offers.swift — Models/Offers — teklif paketleri
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Kod yok, sadece alanlar. Üç farklı 'teklif' var çünkü her ekran farklı alan ister.
// 
//
//  CreateOfferRequest   giden: tutar + not. ListingDetailViewModel → OfferService.create
//  OfferResponse        gelen: teklif verilince dönen cevap
//  ListingOffer         gelen: Yük Verenin ilanına gelen teklif (taşımacı bilgisiyle). ListingOffersViewModel listeler
//  CarrierProfile       gelen: Taşımacı profili (ortalama puan, tamamlanan iş, yorumlar = CarrierReview). ReviewService döner → CarrierProfileViewModel → CarrierProfileView
//  CreateReviewRequest  giden: puan (1–5) + yorum. RatingViewModel hazırlar → ReviewService.create
//  CarrierOffer         gelen: Taşımacının kendi teklifi (ilan bilgisiyle, listingId + note dahil). MyOffersViewModel listeler, geri çeker (withdraw), tutarını değiştirir (saveAmount)
//  ShipperHistoryOffer  gelen: Yük Verenin geçmiş teklifi. OldOffersViewModel listeler
//  UnseenCount          gelen: Taşımacının görmediği karar sayısı. HomeViewModel rozet için okur
