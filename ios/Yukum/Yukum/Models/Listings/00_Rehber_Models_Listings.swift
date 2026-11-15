//
//  00_Rehber_Models_Listings.swift — Models/Listings/ — İLAN
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: İlan verme, listeleme, filtreleme ve sayaç kalıpları.
//
// DOSYA → TÜR → API UCU
//  Listing.swift               Listing — liste/detay satırı (rota, ağırlık, bütçe, tarih, isFavorite, distanceKm?, myOfferStatus?, shipperId?, status?)
//                                ← GET /listings (Taşımacı) · /listings/mine (Yük Veren) · /listings/favorites
//  CreateListingRequest.swift  CreateListingRequest {title, description?, weightKg, vehicleType, from/to il-ilçe, pickupDate, budget?}
//                                → POST /listings (yeni) · PUT /listings/{id} (düzenle; teklif kabul edilmeden)
//  ListingResponse.swift       ListingResponse ← oluştur/güncelle cevabı
//  OpenListingsFilter.swift    Taşımacının filtresi: il/ilçe, varış ili, bütçe aralığı, araç türü, tarih aralığı, sıralama,
//                              "araçlarıma uygun", maxDistanceKm (bana yakın), ağırlık aralığı
//                              fn queryItems(page:pageSize:lat:lon:) → ?fromCityId=…&maxDistanceKm=… (yalnız DOLU alanlar gider)
//  ListingSort.swift           newest · priceAsc · priceDesc · pickupSoonest (sunucuda) ; "en yakın" konum varsa varsayılan
//  Page.swift                  Page<T> {items, page, pageSize, totalCount} — sayfalı cevap zarfı (sonsuz kaydırma)
//  ListingStats.swift          ListingStats {viewCount, favoriteCount, offerCount} ← GET /listings/{id}/stats (yalnız ilan sahibi)
//  PriceReference.swift        PriceReference (emsal fiyat: aynı rotadaki tamamlanmış işlerin medyanı) ← GET /price-reference?fromCityId&toCityId&vehicleType
//
// KULLANAN: Services/ListingService → HomeViewModel, CreateListingViewModel, ListingDetailViewModel, ListingOffersViewModel,
//           MyListingsViewModel, FavoritesViewModel
// KURAL: Bütçesi boş ilan fiyat filtresine girmez. Araç türü "Farketmez" (Any) her araç filtresinde görünür.
