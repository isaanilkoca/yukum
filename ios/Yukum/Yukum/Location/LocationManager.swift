//
//  LocationManager.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import Foundation
import CoreLocation // [SWIFT] Apple'ın konum çerçevesi: enlem/boylam alma, izin yönetimi | CLLocationManager buradan gelir
import Observation // [SWIFT] @Observable özelliği için: sınıftaki değişkenler değişince ekranın kendini yenilemesini sağlar | Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: LocationManager (telefonun konumu) ──────────────────────────
// │ SAHİBİ    : ViewModels/HomeViewModel (Location/LocationProviding sözleşmesi üzerinden) — View konumu doğrudan tutmaz
// │ AKIŞ      : Toggle "Yakınımdakiler" açılır → HomeView .onChange → HomeViewModel.nearMeChanged → location.request() → izin/konum → coordinate dolar
// │ ÇIKIŞ     : HomeViewModel.load() konumu okur → ListingService.openListings(lat:lon:) → sunucu mesafeye göre sıralar
// │ DELEGATE  : CLLocationManagerDelegate: iOS konum olayı olunca aşağıdaki 3 fonksiyonu KENDİSİ çağırır (biz çağırmayız)
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: telefonun konumunu bulur ve kullanıcıdan konum izni ister.
// NEDEN ayrı sınıf: konum özelliği (izin, hata, sonuç) ekran koduyla karışmasın | ileride başka ekranlar da aynı sınıfı kullanabilir
// BAĞLANTI: ViewModels/HomeViewModel (Taşımacı) bunu LocationProviding sözleşmesi üzerinden tutar → "Yakınımdakiler" açılınca request() çağrılır → konum gelince coordinate dolar → HomeViewModel API'ye lat/lon gönderir
// @Observable [SWIFT]: bu sınıftaki değişkenler değişince onları okuyan ekranlar kendiliğinden yenilenir | struct'taki @State'in sınıf (class) karşılığı gibi düşün
// NSObject [SWIFT]: Apple'ın eski çerçeveleri (CoreLocation) bu temel sınıfı ister | CLLocationManagerDelegate: "konum olayları olunca beni ara" sözleşmesi

// ─── DELEGATE NEDİR? (bu sınıfın en önemli fikri) ───
// Delegate bir KOMUT değil, bir DÜZEN: "bir işi ben yapmam, bitince bana haber ver" anlaşması.
// Konum bulmak anında bitmez (uydu, ağ, kullanıcı izni gerekir), bu yüzden "konumu ver" diye bir değer DÖNMEZ. Bunun yerine 3 parça kurulur:
//   ① SÖZLEŞME  : aşağıdaki sınıf başlığındaki "CLLocationManagerDelegate" = "bu sınıf konum olaylarını karşılamayı kabul ediyor" | Apple'ın istediği fonksiyonlar bu sözleşmede yazılı
//   ② BAĞLANTI  : init içindeki "manager.delegate = self" = konum motoruna "olay olunca BANA haber ver" demek
//   ③ KARŞILAYAN: en alttaki 3 fonksiyon (didUpdateLocations, didFailWithError, locationManagerDidChangeAuthorization) = çalan telefon | adlarını Apple belirler, değiştirilemez | BİZ çağırmayız, iOS çağırır
// Bu yüzden o fonksiyonların içinde "delegate" kelimesi geçmez: onları delegate yapan ① ve ②.
//
// ─── KONUM İSTEME AKIŞI (adım adım) ───
//   1) Kullanıcı "Yakınımdakiler"e basar → HomeView request() çağırır
//   2) request() izin durumuna bakar:
//        izin HİÇ SORULMAMIŞ → iOS izin penceresini açar, bu sırada KONUM ALINMAZ, kullanıcı cevap verene kadar beklenir
//        izin VAR            → konum hemen istenir
//        izin YOK (reddedilmiş/kısıtlı) → errorMessage doldurulur, HomeView kullanıcıya "Ayarlar'dan izin ver" der
//   3) Kullanıcı pencerede "İzin ver" ya da "İzin verme"ye basınca iOS locationManagerDidChangeAuthorization'ı çağırır → izin verildiyse konum hemen istenir (düğmeye tekrar basmaya gerek kalmaz)
//   4) Konum bulunursa didUpdateLocations → coordinate dolar → @Observable sayesinde HomeView yenilenir ve API'ye lat/lon gider
//      Konum bulunamazsa didFailWithError → errorMessage "Konum alınamadı"
//
// ─── İZİN DURUMLARI (status) ───
//   .notDetermined       : kullanıcıya hiç sorulmadı (uygulama ilk kez konum istiyor)
//   .authorizedWhenInUse : "Uygulama açıkken izin ver" seçildi → bizim ihtiyacımız olan, yeterli
//   .authorizedAlways    : "Her zaman izin ver" (arka planda da) → biz istemiyoruz ama gelirse kabul ederiz
//   .denied              : kullanıcı "izin verme" dedi → tekrar sorulamaz, yalnız Ayarlar uygulamasından açılabilir
//   .restricted          : cihaz kısıtlı (ebeveyn denetimi/kurumsal) → kullanıcı açamaz
// NEDEN "yalnız bir kez sor": iOS aynı uygulamanın izin penceresini bir kez gösterir; reddedilince kodla tekrar açılamaz, bu yüzden kullanıcıya Ayarlar'a gitmesi söylenir.

@Observable
final class LocationManager : NSObject,CLLocationManagerDelegate { // HAZIR: NSObject, CLLocationManagerDelegate (import CoreLocation) | BİZİM: LocationManager bu dosya

    // status: konum izninin şu anki durumu | NE İŞE YARAR: izin verilmiş mi, reddedilmiş mi, hiç sorulmamış mı | değerler: .notDetermined (sorulmadı), .authorizedWhenInUse (uygulama açıkken izin var), .denied (reddetti), .restricted (cihaz kısıtlı, örn. ebeveyn denetimi)
    // NEREDE KULLANILIR: HomeView reddedilmişse "Ayarlardan izin ver" uyarısı gösterir | başlangıç değeri init içinde atanır
    var status : CLAuthorizationStatus // CLAuthorizationStatus [SWIFT]: konum izni durumu
    
    //coordinate: bulunan konum (enlem + boylam) | CLLocationCoordinate2D [SWIFT]: latitude (enlem) ve longitude (boylam) taşıyan hazır tip | ? = henüz konum yoksa nil
    // NEREDE KULLANILIR: HomeView dolunca openListings(lat:lon:) ile API'ye gönderir
    var coordinate : CLLocationCoordinate2D?
    
    // errorMessage: kullanıcıya gösterilecek hata yazısı | NE İŞE YARAR: izin kapalı ya da konum alınamadı | nil: hata yok
    var errorMessage : String?
    
    //manager: Apple'ın hazır konum motoru | CLLocationManager [SWIFT]: izin isteme ve konum alma işini yapan asıl nesne, biz onu yönetiyoruz
    // @ObservationIgnored: bu değişken değişse bile ekran yenilenmesin (ekranın ilgilendiği şey manager değil, sonuçlar) | private: yalnız bu sınıf görür
    @ObservationIgnored private let manager = CLLocationManager() // @ObservationIgnored [SWIFT]: bu değişken değişse bile ekran yenilenmesin | HAZIR: CLLocationManager (import CoreLocation) = Apple'ın konum motoru
    
    // init: sınıf oluşturulurken bir kez çalışır | override: NSObject'in init'ini ezeriz
    override init(){
        status = manager.authorizationStatus // başlangıç izin durumunu motordan oku (init'te her değişkene değer verilmeden super.init çağrılamaz, bu yüzden önce bu satır)
        super.init() // temel sınıfı (NSObject) başlat | Swift kuralı: kendi değişkenlerimiz hazır olunca çağrılır
        manager.delegate = self // delegate: "konumla ilgili olay olunca BU sınıfın aşağıdaki fonksiyonlarını çağır" | self = bu nesne | ZİNCİR: motora "olay olunca beni ara" dedik → olaylar aşağıdaki 3 fonksiyona düşer
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // istenen hassasiyet: kilometre düzeyi | NEDEN: ilan sıralaması için sokak hassasiyeti gerekmez; daha az pil harcar ve daha hızlı bulur
    }
    
    
    // request: "Yakınımdakiler" düğmesi bunu çağırır | NE İŞE YARAR: izin yoksa izin sorar, izin varsa konumu ister
    func request (){
        switch manager.authorizationStatus { // switch [SWIFT]: değere göre dallanır
        case.notDetermined: // henüz hiç sorulmadı
            manager.requestWhenInUseAuthorization() // iOS'un izin penceresini gösterir ("Uygulama açıkken izin ver" vb.) | metni Info ayarındaki açıklamadır | kullanıcı cevap verince aşağıdaki locationManagerDidChangeAuthorization çağrılır | HAZIR: CLLocationManager.requestWhenInUseAuthorization (import CoreLocation) → iOS izin penceresi → cevap → locationManagerDidChangeAuthorization
        case.authorizedWhenInUse, .authorizedAlways: // izin zaten var
            manager.requestLocation() // TEK SEFERLİK konum iste | neden sürekli takip değil (startUpdatingLocation): biz yalnız bir kez sıralamak istiyoruz, pil harcamayalım | sonuç aşağıdaki didUpdateLocations'a gelir | HAZIR: CLLocationManager.requestLocation (import CoreLocation) → iOS konumu bulur → didUpdateLocations'ı çağırır → coordinate dolar → HomeViewModel.load() okur (LocationProviding üzerinden)
        default :  // .denied veya .restricted: izin yok
            errorMessage = "Konum izni kapalı.Ayarlardan izin verebilirsiniz."
        }
        
    }
    
    
    // ─── Aşağıdakiler DELEGATE fonksiyonları: biz çağırmayız, iOS konum olayı olunca bizi çağırır ───
    // izin durumu DEĞİŞİNCE (kullanıcı pencerede "İzin ver"e bastığında) iOS bunu çağırır
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { // _ manager: çağıran motor (bizim manager ile aynı) | HAZIR ad (CLLocationManagerDelegate, import CoreLocation) | içi BİZİM | çağıran iOS
        status = manager.authorizationStatus // yeni durumu sakla ekran yenilenir
        if status == .authorizedWhenInUse || status == .authorizedAlways { // || veya | izin yeni verildiyse
            manager.requestLocation()  // kullanıcı tekrar düğmeye basmak zorunda kalmasın, konumu hemen iste | ZİNCİR: izin yeni verildi → aynı HAZIR requestLocation → didUpdateLocations
        }
    }
    
    // konum bulununca ios bunun cagırır | locations : bulunan konumlar listesi ( genelde tek eleman)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { // HAZIR ad (CLLocationManagerDelegate) | içi BİZİM | çağıran iOS → coordinate dolar → HomeViewModel.reloadKey değişir → load() sıralı listeyi çeker
        coordinate = locations.last?.coordinate // last: listedeki son (en güncel) konum | ?. nil olabilir, boş listede nil kalır | .coordinate: konumdan yalnız enlem/boylamı al
        errorMessage = nil // önceki hata varsa temizle
    }
    
    // konum ALINAMAYINCA iOS bunu çağırır (örn. GPS yok, simülatörde konum ayarlanmamış)
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { // Error [SWIFT]: fırlatılabilir hata türü | HAZIR ad (CLLocationManagerDelegate) | içi BİZİM | çağıran iOS → errorMessage → HomeViewModel.locationError → HomeView kırmızı yazı
        errorMessage = "Konum alınamadı" // basit mesaj | kullanıcı tekrar deneyebilir
    }
    //Neden delegate? Konum bulmak anında bitmez, uydu ve ağ gerektirir. Bu yüzden "konumu ver" diye bir değer dönmez. Konum motoruna "bulunca beni ara" deriz (delegate), bulunca o fonksiyonları çağırır. Daha önceki await ile bekleme mantığına benzer ama eski bir stil.
    
    
}

// LocationManager, LocationProviding sözleşmesini karşılar: ViewModel'ler CoreLocation türlerini (CLLocationCoordinate2D, CLAuthorizationStatus) bilmesin, sade değerler görsün
extension LocationManager: LocationProviding { // extension [SWIFT]: mevcut türe sonradan özellik/uyum ekler | BİZİM: LocationProviding (Location/LocationProviding.swift) → HomeViewModel konumu yalnız bu sözleşmeyle görür, CoreLocation'ı bilmez
    var latitude: Double? { coordinate?.latitude }
    var longitude: Double? { coordinate?.longitude }
    var isDenied: Bool { status == .denied }
}
