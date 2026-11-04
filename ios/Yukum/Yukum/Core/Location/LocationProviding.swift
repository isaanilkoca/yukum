//
//  LocationProviding.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: LocationProviding (konum sözleşmesi) ───────────────────────────
// │ GERÇEK    : Core/Location/LocationManager.swift (CoreLocation) | SAHTE (test): YukumTests/Support/FakeLocation.swift
// │ KULLANAN  : Features/Listings/HomeViewModel (konumu sözleşme üzerinden okur, iOS konum motoruna doğrudan bağlı değildir)
// │ NEDEN     : Konum izni/GPS testte yok; sözleşme sayesinde "konum şu, izin reddedildi" gibi durumlar sahte konumla denenir
// └──────────────────────────────────────────────────────────────────────

// protocol [SWIFT]: "bu üyelere sahip olan her şey bu sözleşmeyi karşılar" | AnyObject: yalnız sınıflar (referans) karşılayabilir
// ⮕ KULLANIM [LocationProviding]: kullanır: HomeViewModel › location, HomeViewModel › init(), LocationManager › locationManager(), FakeLocation (test)
protocol LocationProviding: AnyObject {
    // ⮕ KULLANIM [latitude]: okur: HomeViewModel › load(), HomeViewModel › reloadKey | YAZAR: HomeViewModelTests (test)
    var latitude: Double? { get }      // bulunan konumun enlemi, konum yoksa nil
    // ⮕ KULLANIM [longitude]: okur: HomeViewModel › load(), HomeViewModel › reloadKey | YAZAR: HomeViewModelTests (test)
    var longitude: Double? { get }     // boylamı
    // ⮕ KULLANIM [isDenied]: okur: HomeViewModel › isLocationDenied, HomeViewModel › locationError | YAZAR: HomeViewModelTests (test)
    var isDenied: Bool { get }         // kullanıcı konum iznini reddetti mi (kodla tekrar sorulamaz, yalnız Ayarlar'dan açılır)
    // ⮕ KULLANIM [errorMessage]: okur: HomeViewModel › locationError | YAZAR: HomeViewModelTests (test)
    var errorMessage: String? { get }  // konum alınamadı gibi hata yazısı, yoksa nil
    // ⮕ KULLANIM [request]: çağırır: HomeViewModel › nearMeChanged()
    func request()                     // izin sor / konumu iste
}
