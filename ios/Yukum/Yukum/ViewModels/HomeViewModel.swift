//
//  HomeViewModel.swift
//  Yukum
//

import Foundation
import Observation // [SWIFT] @Observable özelliği: bu sınıftaki değişkenler değişince onları okuyan ekranlar kendiliğinden yenilenir

// ViewModel NEDİR? (MVVM = Model - View - ViewModel)
//   Model     : veri kalıpları (Listing, City...) → Models/ ve Services/
//   View      : ekranın GÖRÜNÜMÜ (SwiftUI) → Views/HomeView.swift | yalnız "ne çizilecek" bilir
//   ViewModel : ekranın DURUMU ve İŞ MANTIĞI (hangi liste, hangi filtre, ne zaman yüklenir, hata yazısı) | bu dosya
// NEDEN: iş mantığı ekranın içinde olunca test edilemez (simülatör gerekir) ve ekran kodu şişer. ViewModel ise sade bir sınıftır:
//   servisler dışarıdan verilir (bağımlılık enjeksiyonu) → testte sahte servis verip mantığı sunucusuz doğrularız (YukumTests/HomeViewModelTests.swift).
// BU SINIF: ana sayfanın durumu. İki role de hizmet eder: Yük Veren (kendi açık ilanları) ve Taşımacı (açık ilanlar + filtre + yakınımdakiler + rozet).
// BAĞLANTI: Views/HomeView.swift bunu @State ile tutar ve okur | servisler: Services/Protocols/
@Observable
final class HomeViewModel { // @Observable [SWIFT]: bu sınıfı "gözlemlenebilir" yapar (eski adıyla ObservableObject + @Published yerine)

    let user: LoginUser // giriş yapan kişi (ad, rol)

    // Bağımlılıklar: gerçek uygulamada varsayılan gerçek servisler, testte sahteleri verilir
    private let listingService: ListingServicing
    private let offerService: OfferServicing
    private let cityService: CityServicing

    // ─── Ekranın durumu (View bunları okur; değişince ekran yenilenir) ───
    var listings: [Listing] = [] // ekrandaki ilan listesi (Yük Veren: kendi açık ilanları, Taşımacı: teklif vermediği açık ilanlar)
    var listError: String? // liste yüklenemezse kırmızı yazılacak mesaj | nil: hata yok
    var unseenCount = 0 // Taşımacı'nın görmediği karar sayısı (kutu ikonundaki rozet) | 0: rozet çizilmez

    // Taşımacı filtresi: kalkış ili / ilçesi | 0 = "Tümü" (filtre yok) | hem Picker seçimini tutar hem API'ye giden filtredir
    var cities: [City] = [] // il Picker'ının listesi (bir kez yüklenir)
    var filterDistricts: [District] = [] // seçilen ilin ilçeleri
    var filterCityId = 0
    var filterDistrictId = 0
    var nearMe = false // "Yakınımdakiler" anahtarı: true iken liste telefonun konumuna göre yakından uzağa sıralanır

    var isShipper: Bool { user.role == "Shipper" } // türetilmiş değer: rol kararı tek yerde (ekran ve mantık aynı tanımı kullanır)

    init(user: LoginUser,
         listingService: ListingServicing = ListingService(),
         offerService: OfferServicing = OfferService(),
         cityService: CityServicing = CityService()) {
        self.user = user
        self.listingService = listingService
        self.offerService = offerService
        self.cityService = cityService
    }

    // load: ana sayfanın verisini API'den çekip durum değişkenlerine yazar
    // coordinate: telefonun konumu (nil: yok) | yalnız "Yakınımdakiler" AÇIKSA ve konum BULUNMUŞSA API'ye gönderilir
    // ÇAĞIRAN: View → .task(id:) (ekran açılınca/filtre değişince/konum bulununca) ve .refreshable (aşağı çekince)
    func load(coordinate: (latitude: Double, longitude: Double)?) async {
        listError = nil // eski hata yazısını temizle | NEDEN: load her yenilemede çalışır; temizlemezsek bir kez çıkan hata sonraki BAŞARILI yüklemeden sonra da ekranda kalırdı
        do {
            if isShipper { // VERİ kararı: rol hangi ucu çağıracağımızı belirler
                listings = try await listingService.myListings() // GET /api/v1/listings/mine
            } else {
                let lat = nearMe ? coordinate?.latitude : nil // nearMe ? A : B kısa if | konum yoksa nil kalır, liste eskisi gibi (en yeni üstte) gelir
                let lon = nearMe ? coordinate?.longitude : nil
                listings = try await listingService.openListings(fromCityId: filterCityId, fromDistrictId: filterDistrictId, lat: lat, lon: lon) // GET /api/v1/listings?...
                if cities.isEmpty { cities = (try? await cityService.cities()) ?? [] } // il listesi yalnız bir kez yüklenir | try?: hata olursa nil | ?? []: nil ise boş liste
                unseenCount = try await offerService.unseenCount() // rozet sayısı
            }
        } catch {
            if let message = error.userMessage { listError = message } // iptal ise (nil) yazı gösterilmez
        }
    }

    // cityFilterChanged: il Picker'ı değişince çağrılır | ilçe seçimi sıfırlanır ve yeni ilin ilçeleri çekilir
    // NEDEN sıfırlama: eski ilin ilçesi yeni ile ait değildir, kalırsa yanlış filtre gider
    func cityFilterChanged(to cityId: Int) async {
        filterDistrictId = 0
        filterDistricts = []
        guard cityId != 0 else { return } // "Tüm İller"e dönüldüyse çekecek ilçe yok
        filterDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // reloadKey: ekranın .task(id:) değeri | bu yazı değişince liste yeniden yüklenir (filtre, anahtar ya da konum değişti)
    func reloadKey(coordinate: (latitude: Double, longitude: Double)?) -> String {
        "\(filterCityId)-\(filterDistrictId)-\(nearMe)-\(coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "-")"
    }
}
