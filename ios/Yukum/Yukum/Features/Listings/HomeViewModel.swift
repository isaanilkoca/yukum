//
//  HomeViewModel.swift
//  Yukum
//

import Foundation
import Observation // [SWIFT] @Observable özelliği: bu sınıftaki değişkenler değişince onları okuyan ekranlar kendiliğinden yenilenir | Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: HomeViewModel ───────────────────────────────────────────────
// │ EKRAN     : Features/Listings/HomeView (@State private var viewModel) — iki rol için ana sayfa
// │ SERVİS    : Features/Listings/ListingServicing → ListingService | OfferServicing → OfferService | CityServicing → CityService
// │ MODEL     : Listing, City, District, LoginUser
// │ AKIŞ      : View .task(id:) → load() → servis → API → Model dizisi → listings değişkeni → @Observable → View yeniden çizer
// │ KONUM/ÇIKIŞ: Core/Location/LocationProviding (konum) ve Core/Networking/SessionRestoring.swift → SessionSigningOut (çıkış) sözleşmeleri; View bunlara doğrudan dokunmaz
// └──────────────────────────────────────────────────────────────────────

// ViewModel NEDİR? (MVVM = Model - View - ViewModel)
//   Model     : veri kalıpları (Listing, City...) → Models/ ve Services/
//   View      : ekranın GÖRÜNÜMÜ (SwiftUI) → Features/Listings/HomeView.swift | yalnız "ne çizilecek" bilir
//   ViewModel : ekranın DURUMU ve İŞ MANTIĞI (hangi liste, hangi filtre, ne zaman yüklenir, hata yazısı) | bu dosya
// NEDEN: iş mantığı ekranın içinde olunca test edilemez (simülatör gerekir) ve ekran kodu şişer. ViewModel ise sade bir sınıftır:
//   servisler dışarıdan verilir (bağımlılık enjeksiyonu) → testte sahte servis verip mantığı sunucusuz doğrularız (YukumTests/HomeViewModelTests.swift).
// BU SINIF: ana sayfanın durumu. İki role de hizmet eder: Yük Veren (kendi açık ilanları) ve Taşımacı (açık ilanlar + filtre + yakınımdakiler + rozet).
// BAĞLANTI: Features/Listings/HomeView.swift bunu @State ile tutar ve okur | servisler: Services/Protocols/
// ⮕ KULLANIM [HomeViewModel]: kullanır: HomeView › viewModel, HomeView › init(), HomeViewModelTests (test)
@Observable
final class HomeViewModel { // @Observable [SWIFT]: bu sınıfı "gözlemlenebilir" yapar (eski adıyla ObservableObject + @Published yerine)

    // ⮕ ZİNCİR: Features/Listings/HomeView: "Hoş Geldin \(viewModel.user.displayName)" | rol kararı isShipper | MODEL: Features/Auth/LoginUser | GELDİĞİ YER: LoginViewModel.loggedInUser → Features/Auth/LoginView.fullScreenCover → HomeView(user:)
    // ⮕ KULLANIM [user]: okur: HomeViewModel › isShipper, HomeView › body
    let user: LoginUser // giriş yapan kişi (ad, rol)

    // Bağımlılıklar: gerçek uygulamada varsayılan gerçek servisler, testte sahteleri verilir
    // ⮕ KULLANIM [listingService]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › load()
    private let listingService: ListingServicing
    // ⮕ KULLANIM [offerService]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › load()
    private let offerService: OfferServicing
    // ⮕ KULLANIM [cityService]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › load(), HomeViewModel › cityFilterChanged()
    private let cityService: CityServicing
    // ⮕ KULLANIM [session]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › signOut()
    private let session: SessionSigningOut // çıkış (Core/Networking/AuthSession) | testte sahtesi
    // ⮕ KULLANIM [location]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › isLocationDenied, HomeViewModel › locationError, HomeViewModel › nearMeChanged(), HomeViewModel › load(), HomeViewModel › reloadKey
    private let location: LocationProviding // telefonun konumu (Core/Location/LocationManager) | testte sahtesi

    // ─── Ekranın durumu (View bunları okur; değişince ekran yenilenir) ───
    // ⮕ ZİNCİR: Features/Listings/HomeView: List(viewModel.listings) (Yük Veren ve Taşımacı için iki ayrı liste) → her satır Features/Listings/ListingRow | DOLDURAN: load() | MODEL: [Listing]
    // ⮕ KULLANIM [listings]: YAZAR: HomeViewModel › load() | okur: HomeView › body, HomeViewModelTests (test)
    var listings: [Listing] = [] // ekrandaki ilan listesi (Yük Veren: kendi açık ilanları, Taşımacı: teklif vermediği açık ilanlar)
    // ⮕ ZİNCİR: Features/Listings/HomeView: if let listError → kırmızı Text | DOLDURAN: load()'un catch'i (error.userMessage)
    // ⮕ KULLANIM [listError]: YAZAR: HomeViewModel › load() | okur: HomeViewModelTests (test)
    var listError: String? // liste yüklenemezse kırmızı yazılacak mesaj | nil: hata yok
    // ⮕ ZİNCİR: Features/Listings/HomeView toolbar: kutu ikonundaki kırmızı rozet (> 0 ise çizilir) | DOLDURAN: load() ← OfferService.unseenCount()
    // ⮕ KULLANIM [unseenCount]: YAZAR: HomeViewModel › load() | okur: HomeView › body, HomeViewModelTests (test)
    var unseenCount = 0 // Taşımacı'nın görmediği karar sayısı (kutu ikonundaki rozet) | 0: rozet çizilmez

    // Taşımacı filtresi: kalkış ili / ilçesi | 0 = "Tümü" (filtre yok) | hem Picker seçimini tutar hem API'ye giden filtredir
    // ⮕ ZİNCİR: Features/Listings/HomeView: il Picker'ının satırları (ForEach) | DOLDURAN: load() (yalnız bir kez) ← CityService.cities() | MODEL: [City]
    // ⮕ KULLANIM [cities]: YAZAR: HomeViewModel › load() | okur: HomeView › body
    var cities: [City] = [] // il Picker'ının listesi (bir kez yüklenir)
    // ⮕ ZİNCİR: Features/Listings/HomeView: ilçe Picker'ının satırları | DOLDURAN: cityFilterChanged(to:) ← CityService.districts(cityId:) | MODEL: [District]
    // ⮕ KULLANIM [filterDistricts]: YAZAR: HomeViewModel › cityFilterChanged() | okur: HomeView › body, HomeViewModelTests (test)
    var filterDistricts: [District] = [] // seçilen ilin ilçeleri
    // ⮕ ZİNCİR: Features/Listings/HomeView: Picker("İl", selection: $viewModel.filterCityId) — seçim doğrudan buraya yazılır (@Bindable) | load()'da openListings(fromCityId:) filtresi olarak API'ye gider
    // ⮕ KULLANIM [filterCityId]: okur: HomeViewModel › load(), HomeViewModel › reloadKey, HomeView › body | bağlar(okur+yazar): HomeView › body | YAZAR: HomeViewModelTests (test)
    var filterCityId = 0
    // ⮕ ZİNCİR: Features/Listings/HomeView: Picker("İlçe", selection: $viewModel.filterDistrictId) | load()'da openListings(fromDistrictId:) filtresi olarak API'ye gider
    // ⮕ KULLANIM [filterDistrictId]: okur: HomeViewModel › load(), HomeViewModel › reloadKey, HomeViewModelTests (test) | YAZAR: HomeViewModel › cityFilterChanged(), HomeViewModelTests (test) | bağlar(okur+yazar): HomeView › body
    var filterDistrictId = 0
    // ⮕ ZİNCİR: Features/Listings/HomeView: Toggle("Yakınımdakiler", isOn: $viewModel.nearMe) | true iken load() konumu API'ye gönderir (lat/lon) ve sunucu en yakından uzağa sıralar
    // ⮕ KULLANIM [nearMe]: okur: HomeViewModel › isLocationDenied, HomeViewModel › locationError, HomeViewModel › load(), HomeViewModel › reloadKey, HomeView › body | bağlar(okur+yazar): HomeView › body | YAZAR: HomeViewModelTests (test)
    var nearMe = false // "Yakınımdakiler" anahtarı: true iken liste telefonun konumuna göre yakından uzağa sıralanır

    // ⮕ ZİNCİR: Features/Listings/HomeView: if viewModel.isShipper { Yük Veren ekranı } else { Taşımacı ekranı } ve toolbar düğmeleri | kaynak: user.role
    // ⮕ KULLANIM [isShipper]: okur: HomeViewModel › load(), HomeView › body
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

    // ⮕ ZİNCİR: Features/Listings/HomeView: "Konum izni kapalı" + "Ayarları aç" satırı yalnız nearMe açıkken ve izin reddedilmişse görünür | kaynak: Core/Location/LocationManager.isDenied
    // ⮕ KULLANIM [isLocationDenied]: okur: HomeView › body, HomeViewModelTests (test)
    var isLocationDenied: Bool { nearMe && location.isDenied }
    // ⮕ ZİNCİR: Features/Listings/HomeView: konum alınamadı gibi kırmızı küçük yazı (yalnız nearMe açıkken ve izin reddedilmemişse) | kaynak: Core/Location/LocationManager.errorMessage
    // ⮕ KULLANIM [locationError]: okur: HomeView › body, HomeViewModelTests (test)
    var locationError: String? { nearMe && !location.isDenied ? location.errorMessage : nil }

    // nearMeChanged: "Yakınımdakiler" anahtarı değişince çağrılır | açıldıysa konum motoruna "izin sor ve konumu bul" der
    // izin ya da konum gelene kadar liste eskisi gibi kalır, konum gelince reloadKey değişir ve load() listeyi sıralı yeniler
    // ⮕ ZİNCİR: Features/Listings/HomeView: Toggle üzerindeki .onChange(of: viewModel.nearMe) → viewModel.nearMeChanged(to:) → Core/Location/LocationManager.request() (izin penceresi / konum)
    // ⮕ KULLANIM [nearMeChanged]: çağırır: HomeView › body, HomeViewModelTests (test)
    func nearMeChanged(to isOn: Bool) {
        if isOn { location.request() }
    }

    // signOut: "Çıkış Yap" düğmesi | önce yerel oturum silinir (Keychain + bellek), sonra sunucuya haber verilir (jeton orada da iptal edilsin)
    // ⮕ ZİNCİR: Features/Listings/HomeView: Button("Çıkış Yap") { Task { await viewModel.signOut(); dismiss() } } → Core/Networking/AuthSession.signOut() → POST /api/v1/auth/logout
    // ⮕ KULLANIM [signOut]: çağırır: HomeViewModel › signOut(), HomeView › body, HomeViewModelTests (test)
    func signOut() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        await session.signOut() // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }

    // load: ana sayfanın verisini API'den çekip durum değişkenlerine yazar
    // Konum, ViewModel'in kendi `location`ından okunur: yalnız "Yakınımdakiler" AÇIKSA ve konum BULUNMUŞSA API'ye gönderilir
    // ÇAĞIRAN: View → .task(id:) (ekran açılınca/filtre değişince/konum bulununca) ve .refreshable (aşağı çekince)
    // ⮕ ZİNCİR: Features/Listings/HomeView: .task(id: reloadKey) ve List'lerdeki .refreshable | Yük Veren → ListingService.myListings() | Taşımacı → ListingService.openListings(...) + CityService.cities() + OfferService.unseenCount()
    // ⮕ KULLANIM [load]: çağırır: HomeView › body, HomeViewModelTests (test)
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
    // ⮕ ZİNCİR: Features/Listings/HomeView: il Picker'ındaki .onChange(of: viewModel.filterCityId) → Task { await viewModel.cityFilterChanged(to:) } | CityService.districts(cityId:)
    // ⮕ KULLANIM [cityFilterChanged]: çağırır: HomeView › body, HomeViewModelTests (test)
    func cityFilterChanged(to cityId: Int) async {
        filterDistrictId = 0
        filterDistricts = []
        guard cityId != 0 else { return } // "Tüm İller"e dönüldüyse çekecek ilçe yok | guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
        filterDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // reloadKey: ekranın .task(id:) değeri | bu yazı değişince liste yeniden yüklenir (filtre, anahtar ya da konum değişti)
    // ⮕ ZİNCİR: Features/Listings/HomeView: .task(id: viewModel.reloadKey) — bu yazı değişince (filtre, anahtar, konum) SwiftUI task'ı yeniden çalıştırır → load()
    // ⮕ KULLANIM [reloadKey]: okur: HomeView › body, HomeViewModelTests (test)
    var reloadKey: String {
        "\(filterCityId)-\(filterDistrictId)-\(nearMe)-\(location.latitude.map { String($0) } ?? "-"),\(location.longitude.map { String($0) } ?? "-")"
    }
}
