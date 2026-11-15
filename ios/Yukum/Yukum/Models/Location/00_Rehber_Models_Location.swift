//
//  00_Rehber_Models_Location.swift — Models/Location/ — TELEFONUN KONUMU
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: "Bana yakın" ve "en yakın" sıralaması için anlık konum. Konum SUNUCUDA SAKLANMAZ; yalnız o sorguda gönderilir.
//
//  LocationProviding.swift  protokol: latitude?, longitude?, isDenied, errorMessage, request() — ViewModel buna bağlı (testte FakeLocation)
//  LocationManager.swift    gerçek uygulama: CoreLocation; izin yalnız ihtiyaç anında istenir (kullanıcı "bana yakın"ı açınca)
//                           fn request(), locationManager(didUpdateLocations:), locationManagerDidChangeAuthorization
//
// KULLANAN: HomeViewModel (nearMeChanged, applyFilter) → ListingService.openListings(lat:lon:)
// İzin reddedilirse: HomeView "Konum izni kapalı · Ayarları aç" satırı gösterir.
