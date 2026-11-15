//
//  00_Rehber_Models_Vehicles.swift — Models/Vehicles/ — ARAÇLAR
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Taşımacının araçları ve araç türleri (ilan, filtre, teklif ve Araçlarım'da tek kaynak).
//
//  VehicleType.swift  Tır (Truck) · Kamyon (Lorry) · Kamyonet (Pickup) · Frigorifik (Refrigerated) · Otomobil (Car) · Diğer (Other)
//                     · Farketmez (Any — YALNIZ ilanda; her araç filtresinde görünür, araç kaydında geçersiz)
//                     listingOptions / vehicleOptions: hangi ekranda hangi seçenekler · title: Türkçe ad
//  Vehicle.swift      Vehicle (Araçlarım: plaka dahil) ← GET /api/v1/vehicles · hasDetails: marka+model+yıl dolu mu
//                     VehicleBody {type, plateNumber, capacityKg?, brand, model, year} → POST/PUT /api/v1/vehicles
//                     PublicVehicle (Taşımacı profilinde başkasının gördüğü: PLAKA YOK)
//
// KURALLAR: plaka + marka + model + yıl ZORUNLU · araçsız Taşımacı teklif VEREMEZ · teklif bir araçla verilir (Yük Veren aracı görür)
//           "araçlarıma uygun" filtresi: büyük araç küçüğün işini de yapar, frigorifik ayrı (backend VehicleCompatibility)
// KULLANAN: Services/VehicleService → VehiclesViewModel, ListingDetailViewModel (teklifte araç seçimi), CreateListingViewModel
