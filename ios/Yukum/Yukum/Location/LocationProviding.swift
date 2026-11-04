//
//  LocationProviding.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: LocationProviding (konum sözleşmesi) ───────────────────────────
// │ GERÇEK    : Location/LocationManager.swift (CoreLocation) | SAHTE (test): YukumTests/Support/FakeLocation.swift
// │ KULLANAN  : ViewModels/HomeViewModel (konumu sözleşme üzerinden okur, iOS konum motoruna doğrudan bağlı değildir)
// │ NEDEN     : Konum izni/GPS testte yok; sözleşme sayesinde "konum şu, izin reddedildi" gibi durumlar sahte konumla denenir
// └──────────────────────────────────────────────────────────────────────

// protocol [SWIFT]: "bu üyelere sahip olan her şey bu sözleşmeyi karşılar" | AnyObject: yalnız sınıflar (referans) karşılayabilir
protocol LocationProviding: AnyObject {
    var latitude: Double? { get }      // bulunan konumun enlemi, konum yoksa nil
    var longitude: Double? { get }     // boylamı
    var isDenied: Bool { get }         // kullanıcı konum iznini reddetti mi (kodla tekrar sorulamaz, yalnız Ayarlar'dan açılır)
    var errorMessage: String? { get }  // konum alınamadı gibi hata yazısı, yoksa nil
    func request()                     // izin sor / konumu iste
}
