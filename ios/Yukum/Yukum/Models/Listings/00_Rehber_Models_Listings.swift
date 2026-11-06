//
//  00_Rehber_Models_Listings.swift — Models/Listings — ilan paketleri
//  (Bu dosyada kod yok; klasörün ilk dosyası olarak ne nerede olduğunu anlatır.)
//

// Kod yok, sadece alanlar.
// 
//
//  Listing               gelen: tek ilan (başlık, yük, şehirler, bütçe, durum). ListingService döner; HomeViewModel listeler, ListingRow çizer
//  PriceReference        gelen: emsal fiyat (medyan tutar + örnek sayısı). ListingService.priceReference döner → ListingDetailViewModel → ilan detayında "Bu rotada emsal fiyat"
//  CreateListingRequest  giden: yeni ilan. CreateListingViewModel hazırlar → ListingService.create
//  ListingResponse       gelen: ilan açılınca dönen cevap
//  Page<Item>            gelen: API'nin sayfa zarfı (items, page, pageSize, totalCount). APIClient çözer → ListingService.openListings döner → HomeViewModel .items'ı okur
//  OpenListingsFilter    giden: Taşımacı liste filtresi tek pakette (il, ilçe, varış, fiyat, araç, tarih, sıralama). HomeViewModel doldurur → queryItems() adresin ?...kısmını kurar
//  ListingSort           seçenek: sıralama (En yeni / Fiyat artan / azalan). rawValue API'deki sort değeri; OpenListingsFilter.sort tutar
