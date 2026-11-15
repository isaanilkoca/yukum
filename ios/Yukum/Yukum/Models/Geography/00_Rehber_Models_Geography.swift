//
//  00_Rehber_Models_Geography.swift — Models/Geography/ — İL VE İLÇE
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: 81 il / 973 ilçe (backend docs/veri/il-ilce.json'dan tohumlanır). İl numarası = plaka kodu.
//
//  City.swift      City {id (plaka), name}                   ← GET /api/v1/cities              (anonim)
//  District.swift  District {id, name}                        ← GET /api/v1/cities/{id}/districts (anonim)
//                  (ilçe merkez koordinatları yalnız SUNUCUDA: "bana yakın" mesafeyi sunucu hesaplar, telefon yalnız kendi konumunu yollar)
//
// KULLANAN: Services/CityService → CreateListingViewModel (il seçilince ilçeler gelir), HomeViewModel (filtre), AccountInfoViewModel
