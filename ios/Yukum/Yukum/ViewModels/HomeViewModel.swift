//
//  HomeViewModel.swift
//  Yukum
//

import Foundation
import Observation // [SWIFT] @Observable özelliği: bu sınıftaki değişkenler değişince onları okuyan ekranlar kendiliğinden yenilenir | Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: HomeViewModel ───────────────────────────────────────────────
// │ EKRAN     : Views/HomeView (@State private var viewModel) — iki rol için ana sayfa
// │ SERVİS    : Services/Protocols/ListingServicing → ListingService | OfferServicing → OfferService | CityServicing → CityService
// │ MODEL     : Listing, City, District, LoginUser
// │ AKIŞ      : View .task(id:) → load() → servis → API → Model dizisi → listings değişkeni → @Observable → View yeniden çizer
// │ KONUM/ÇIKIŞ: Location/LocationProviding (konum) ve Services/Protocols/SessionRestoring.swift → SessionSigningOut (çıkış) sözleşmeleri; View bunlara doğrudan dokunmaz
// │ HAZIR (Swift/Apple) [SWIFT] : @Observable, async, await, guard, try?, String, Int, Bool, Observation
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: HomeViewModel | fonksiyonlar: nearMeChanged, signOut, load, cityFilterChanged | değişken/durumlar: user, listingService, offerService, cityService, session, location, listings, listError, unseenCount, cities …
// └──────────────────────────────────────────────────────────────────────

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

    // ⮕ ZİNCİR: Views/HomeView: "Hoş Geldin \(viewModel.user.displayName)" | rol kararı isShipper | MODEL: Models/Auth/LoginUser | GELDİĞİ YER: LoginViewModel.loggedInUser → Views/LoginView.fullScreenCover → HomeView(user:)
    let user: LoginUser // giriş yapan kişi (ad, rol)

    // Bağımlılıklar: gerçek uygulamada varsayılan gerçek servisler, testte sahteleri verilir
    private let listingService: ListingServicing
    private let offerService: OfferServicing
    private let cityService: CityServicing
    private let session: SessionSigningOut // çıkış (Networking/AuthSession) | testte sahtesi
    private let location: LocationProviding // telefonun konumu (Location/LocationManager) | testte sahtesi

    // ─── Ekranın durumu (View bunları okur; değişince ekran yenilenir) ───
    // ⮕ ZİNCİR: Views/HomeView: List(viewModel.listings) (Yük Veren ve Taşımacı için iki ayrı liste) → her satır Views/ListingRow | DOLDURAN: load() | MODEL: [Listing]
    var listings: [Listing] = [] // ekrandaki ilan listesi (Yük Veren: kendi açık ilanları, Taşımacı: teklif vermediği açık ilanlar)
    // ⮕ ZİNCİR: Views/HomeView: if let listError → kırmızı Text | DOLDURAN: load()'un catch'i (error.userMessage)
    var listError: String? // liste yüklenemezse kırmızı yazılacak mesaj | nil: hata yok
    // ⮕ ZİNCİR: Views/HomeView toolbar: kutu ikonundaki kırmızı rozet (> 0 ise çizilir) | DOLDURAN: load() ← OfferService.unseenCount()
    var unseenCount = 0 // Taşımacı'nın görmediği karar sayısı (kutu ikonundaki rozet) | 0: rozet çizilmez

    // Taşımacı filtresi: kalkış ili / ilçesi | 0 = "Tümü" (filtre yok) | hem Picker seçimini tutar hem API'ye giden filtredir
    // ⮕ ZİNCİR: Views/HomeView: il Picker'ının satırları (ForEach) | DOLDURAN: load() (yalnız bir kez) ← CityService.cities() | MODEL: [City]
    var cities: [City] = [] // il Picker'ının listesi (bir kez yüklenir)
    // ⮕ ZİNCİR: Views/HomeView: ilçe Picker'ının satırları | DOLDURAN: cityFilterChanged(to:) ← CityService.districts(cityId:) | MODEL: [District]
    var filterDistricts: [District] = [] // seçilen ilin ilçeleri
    // ⮕ ZİNCİR: Views/HomeView: Picker("İl", selection: $viewModel.filterCityId) — seçim doğrudan buraya yazılır (@Bindable) | load()'da openListings(fromCityId:) filtresi olarak API'ye gider
    var filterCityId = 0
    // ⮕ ZİNCİR: Views/HomeView: Picker("İlçe", selection: $viewModel.filterDistrictId) | load()'da openListings(fromDistrictId:) filtresi olarak API'ye gider
    var filterDistrictId = 0
    // ⮕ ZİNCİR: Views/HomeView: Toggle("Yakınımdakiler", isOn: $viewModel.nearMe) | true iken load() konumu API'ye gönderir (lat/lon) ve sunucu en yakından uzağa sıralar
    var nearMe = false // "Yakınımdakiler" anahtarı: true iken liste telefonun konumuna göre yakından uzağa sıralanır

    // ⮕ ZİNCİR: Views/HomeView: if viewModel.isShipper { Yük Veren ekranı } else { Taşımacı ekranı } ve toolbar düğmeleri | kaynak: user.role
    var isShipper: Bool { user.role == "Shipper" } // türetilmiş değer: rol kararı tek yerde (ekran ve mantık aynı tanımı kullanır)

    init(user: LoginUser,
         listingService: ListingServicing = ListingService(),
         offerService: OfferServicing = OfferService(),
         cityService: CityServicing = CityService(),
         session: SessionSigningOut = AuthSession.shared,
         location: LocationProviding = LocationManager()) {
        self.user = user
        self.listingService = listingService
        self.offerService = offerService
        self.cityService = cityService
        self.session = session
        self.location = location
    }

    // ⮕ ZİNCİR: Views/HomeView: "Konum izni kapalı" + "Ayarları aç" satırı yalnız nearMe açıkken ve izin reddedilmişse görünür | kaynak: Location/LocationManager.isDenied
    var isLocationDenied: Bool { nearMe && location.isDenied }
    // ⮕ ZİNCİR: Views/HomeView: konum alınamadı gibi kırmızı küçük yazı (yalnız nearMe açıkken ve izin reddedilmemişse) | kaynak: Location/LocationManager.errorMessage
    var locationError: String? { nearMe && !location.isDenied ? location.errorMessage : nil }

    // nearMeChanged: "Yakınımdakiler" anahtarı değişince çağrılır | açıldıysa konum motoruna "izin sor ve konumu bul" der
    // izin ya da konum gelene kadar liste eskisi gibi kalır, konum gelince reloadKey değişir ve load() listeyi sıralı yeniler
    // ⮕ ZİNCİR: Views/HomeView: Toggle üzerindeki .onChange(of: viewModel.nearMe) → viewModel.nearMeChanged(to:) → Location/LocationManager.request() (izin penceresi / konum)
    func nearMeChanged(to isOn: Bool) {
        if isOn { location.request() }
    }

    // signOut: "Çıkış Yap" düğmesi | önce yerel oturum silinir (Keychain + bellek), sonra sunucuya haber verilir (jeton orada da iptal edilsin)
    // ⮕ ZİNCİR: Views/HomeView: Button("Çıkış Yap") { Task { await viewModel.signOut(); dismiss() } } → Networking/AuthSession.signOut() → POST /api/v1/auth/logout
    func signOut() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        await session.signOut() // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }

    // load: ana sayfanın verisini API'den çekip durum değişkenlerine yazar
    // Konum, ViewModel'in kendi `location`ından okunur: yalnız "Yakınımdakiler" AÇIKSA ve konum BULUNMUŞSA API'ye gönderilir
    // ÇAĞIRAN: View → .task(id:) (ekran açılınca/filtre değişince/konum bulununca) ve .refreshable (aşağı çekince)
    // ⮕ ZİNCİR: Views/HomeView: .task(id: reloadKey) ve List'lerdeki .refreshable | Yük Veren → ListingService.myListings() | Taşımacı → ListingService.openListings(...) + CityService.cities() + OfferService.unseenCount()
    func load() async {
        listError = nil // eski hata yazısını temizle | NEDEN: load her yenilemede çalışır; temizlemezsek bir kez çıkan hata sonraki BAŞARILI yüklemeden sonra da ekranda kalırdı
        do {
            if isShipper { // VERİ kararı: rol hangi ucu çağıracağımızı belirler
                listings = try await listingService.myListings() // GET /api/v1/listings/mine
            } else {
                let lat = nearMe ? location.latitude : nil // nearMe ? A : B kısa if | konum yoksa nil kalır, liste eskisi gibi (en yeni üstte) gelir
                let lon = nearMe ? location.longitude : nil
                listings = try await listingService.openListings(fromCityId: filterCityId, fromDistrictId: filterDistrictId, lat: lat, lon: lon) // GET /api/v1/listings?...
                if cities.isEmpty { cities = (try? await cityService.cities()) ?? [] } // il listesi yalnız bir kez yüklenir | try?: hata olursa nil | ?? []: nil ise boş liste | try? [SWIFT]: hata olursa çökme, nil ver
                unseenCount = try await offerService.unseenCount() // rozet sayısı
            }
        } catch {
            if let message = error.userMessage { listError = message } // iptal ise (nil) yazı gösterilmez
        }
    }

    // cityFilterChanged: il Picker'ı değişince çağrılır | ilçe seçimi sıfırlanır ve yeni ilin ilçeleri çekilir
    // NEDEN sıfırlama: eski ilin ilçesi yeni ile ait değildir, kalırsa yanlış filtre gider
    // ⮕ ZİNCİR: Views/HomeView: il Picker'ındaki .onChange(of: viewModel.filterCityId) → Task { await viewModel.cityFilterChanged(to:) } | CityService.districts(cityId:)
    func cityFilterChanged(to cityId: Int) async {
        filterDistrictId = 0
        filterDistricts = []
        guard cityId != 0 else { return } // "Tüm İller"e dönüldüyse çekecek ilçe yok | guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
        filterDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // reloadKey: ekranın .task(id:) değeri | bu yazı değişince liste yeniden yüklenir (filtre, anahtar ya da konum değişti)
    // ⮕ ZİNCİR: Views/HomeView: .task(id: viewModel.reloadKey) — bu yazı değişince (filtre, anahtar, konum) SwiftUI task'ı yeniden çalıştırır → load()
    var reloadKey: String {
        "\(filterCityId)-\(filterDistrictId)-\(nearMe)-\(location.latitude.map { String($0) } ?? "-"),\(location.longitude.map { String($0) } ?? "-")"
    }
}
