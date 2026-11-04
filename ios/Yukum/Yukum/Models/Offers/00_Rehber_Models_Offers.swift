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
//  CarrierOffer         gelen: Taşımacının kendi teklifi (ilan bilgisiyle). MyOffersViewModel listeler
//  ShipperHistoryOffer  gelen: Yük Verenin geçmiş teklifi. OldOffersViewModel listeler
//  UnseenCount          gelen: Taşımacının görmediği karar sayısı. HomeViewModel rozet için okur
