//
//  HomeViewModel.swift
//  Yukum
//

import Foundation
import Observation // [SWIFT] @Observable özelliği: bu sınıftaki değişkenler değişince onları okuyan ekranlar kendiliğinden yenilenir | Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: HomeViewModel ───────────────────────────────────────────────
// │ EKRAN     : Views/HomeView (@State private var viewModel) — iki rol için ana sayfa
// │ SERVİS    : Models/Services/Protocols/ListingServicing → ListingService | OfferServicing → OfferService | CityServicing → CityService
// │ MODEL     : Listing, City, District, LoginUser
// │ AKIŞ      : View .task(id:) → load() → servis → API → Model dizisi → listings değişkeni → @Observable → View yeniden çizer
// │ KONUM/ÇIKIŞ: Models/Location/LocationProviding (konum) ve Models/Services/Protocols/SessionRestoring.swift → SessionSigningOut (çıkış) sözleşmeleri; View bunlara doğrudan dokunmaz
// └──────────────────────────────────────────────────────────────────────

// ViewModel NEDİR? (MVVM = Model - View - ViewModel)
//   Model     : veri kalıpları (Listing, City...) → Models/ ve Services/
//   View      : ekranın GÖRÜNÜMÜ (SwiftUI) → Views/HomeView.swift | yalnız "ne çizilecek" bilir
//   ViewModel : ekranın DURUMU ve İŞ MANTIĞI (hangi liste, hangi filtre, ne zaman yüklenir, hata yazısı) | bu dosya
// NEDEN: iş mantığı ekranın içinde olunca test edilemez (simülatör gerekir) ve ekran kodu şişer. ViewModel ise sade bir sınıftır:
//   servisler dışarıdan verilir (bağımlılık enjeksiyonu) → testte sahte servis verip mantığı sunucusuz doğrularız (YukumTests/HomeViewModelTests.swift).
// BU SINIF: ana sayfanın durumu. İki role de hizmet eder: Yük Veren (kendi açık ilanları) ve Taşımacı (açık ilanlar + filtre + yakınımdakiler + rozet).
// BAĞLANTI: Views/HomeView.swift bunu @State ile tutar ve okur | servisler: Services/Protocols/
// ⮕ KULLANIM [HomeViewModel]: kullanır: HomeView › viewModel, HomeView › init(), HomeViewModelTests (test)
@Observable
final class HomeViewModel { // @Observable [SWIFT]: bu sınıfı "gözlemlenebilir" yapar (eski adıyla ObservableObject + @Published yerine)

    // ⮕ ZİNCİR: Views/HomeView: "Hoş Geldin \(viewModel.user.displayName)" | rol kararı isShipper | MODEL: Models/Auth/LoginUser | GELDİĞİ YER: LoginViewModel.loggedInUser → Views/LoginView.fullScreenCover → HomeView(user:)
    // ⮕ KULLANIM [user]: okur: HomeViewModel › isShipper, HomeView › body
    let user: LoginUser // giriş yapan kişi (ad, rol)

    // Bağımlılıklar: gerçek uygulamada varsayılan gerçek servisler, testte sahteleri verilir
    // ⮕ KULLANIM [listingService]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › load()
    private let listingService: ListingServicing
    // ⮕ KULLANIM [offerService]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › load()
    private let offerService: OfferServicing
    private let notificationService: NotificationServicing // [BİZİM] bildirim servisi (sözleşme) | BAĞLANTI: Models/Services/NotificationService
    var unreadNotifications = 0 // zil rozetindeki sayı | 0 ise rozet çizilmez | OKUR: HomeView toolbar
    private let push: PushRegistering // [BİZİM] telefon bildirimi kaydı (sözleşme) | BAĞLANTI: Models/Notifications/PushManager
    // ⮕ KULLANIM [cityService]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › load(), HomeViewModel › cityFilterChanged()
    private let cityService: CityServicing
    // ⮕ KULLANIM [session]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › signOut()
    private let session: SessionSigningOut // çıkış (Models/Networking/AuthSession) | testte sahtesi
    // ⮕ KULLANIM [location]: YAZAR: HomeViewModel › init() | okur: HomeViewModel › isLocationDenied, HomeViewModel › locationError, HomeViewModel › nearMeChanged(), HomeViewModel › load(), HomeViewModel › reloadKey
    private let location: LocationProviding // telefonun konumu (Models/Location/LocationManager) | testte sahtesi

    // ─── Ekranın durumu (View bunları okur; değişince ekran yenilenir) ───
    // ⮕ ZİNCİR: Views/HomeView: List(viewModel.listings) (Yük Veren ve Taşımacı için iki ayrı liste) → her satır Views/ListingRow | DOLDURAN: load() | MODEL: [Listing]
    // ⮕ KULLANIM [listings]: YAZAR: HomeViewModel › load() | okur: HomeView › body, HomeViewModelTests (test)
    var listings: [Listing] = [] // ekrandaki ilan listesi (Yük Veren: kendi açık ilanları, Taşımacı: teklif vermediği açık ilanlar)
    // ⮕ ZİNCİR: Views/HomeView: if let listError → kırmızı Text | DOLDURAN: load()'un catch'i (error.userMessage)
    // ⮕ KULLANIM [listError]: YAZAR: HomeViewModel › load() | okur: HomeViewModelTests (test)
    var listError: String? // liste yüklenemezse kırmızı yazılacak mesaj | nil: hata yok
    // ⮕ ZİNCİR: Views/HomeView toolbar: kutu ikonundaki kırmızı rozet (> 0 ise çizilir) | DOLDURAN: load() ← OfferService.unseenCount()
    // ⮕ KULLANIM [unseenCount]: YAZAR: HomeViewModel › load() | okur: HomeView › body, HomeViewModelTests (test)
    var unseenCount = 0 // Taşımacı'nın görmediği karar sayısı (kutu ikonundaki rozet) | 0: rozet çizilmez
    
    // Sayfalama durumu (yalnız Taşımacı listesi) | DOLDURAN: load() ve loadMore() ← Page<Listing> zarfı
    // ZİNCİR: Views/HomeView listenin son satırı .onAppear → loadMore() | alttaki yükleme göstergesi isLoadingMore'a bağlı
    private(set) var page = 1 // private(set) [SWIFT]: dışarıdan okunur, yalnız bu sınıf yazar
    private(set) var totalCount = 0 // sunucunun söylediği TOPLAM kayıt (filtreye uyan hepsi)
    private(set) var isLoadingMore = false // true iken ikinci loadMore istenmez
    var hasMore: Bool { listings.count < totalCount } // türetilmiş: başka sayfa var mı

    // Taşımacı filtresi: kalkış ili / ilçesi | 0 = "Tümü" (filtre yok) | hem Picker seçimini tutar hem API'ye giden filtredir
    // ⮕ ZİNCİR: Views/HomeView: il Picker'ının satırları (ForEach) | DOLDURAN: load() (yalnız bir kez) ← CityService.cities() | MODEL: [City]
    // ⮕ KULLANIM [cities]: YAZAR: HomeViewModel › load() | okur: HomeView › body
    var cities: [City] = [] // il Picker'ının listesi (bir kez yüklenir)
    // ⮕ ZİNCİR: Views/HomeView: ilçe Picker'ının satırları | DOLDURAN: cityFilterChanged(to:) ← CityService.districts(cityId:) | MODEL: [District]
    // ⮕ KULLANIM [filterDistricts]: YAZAR: HomeViewModel › cityFilterChanged() | okur: HomeView › body, HomeViewModelTests (test)
    var filterDistricts: [District] = [] // seçilen ilin ilçeleri
    // Taşımacı filtresinin TEK kaynağı | 0 / nil / "" = filtre yok | Picker'lar ve filtre ekranı alanlarına doğrudan bağlanır
    // ZİNCİR: Views/HomeView Picker'ları ($viewModel.filter.fromCityId ...) yazar → reloadKey değişir → .task(id:) → load() → fetchOpen → GET /api/v1/listings?...
    // MODEL: Models/Listings/OpenListingsFilter
    var filter = OpenListingsFilter() // struct [SWIFT]: alanı değişince bütün değer değişmiş sayılır, @Observable ekranı yeniler
    
    // ⮕ ZİNCİR: Views/HomeView: Toggle("Yakınımdakiler", isOn: $viewModel.nearMe) | true iken load() konumu API'ye gönderir (lat/lon) ve sunucu en yakından uzağa sıralar
    // ⮕ KULLANIM [nearMe]: okur: HomeViewModel › isLocationDenied, HomeViewModel › locationError, HomeViewModel › load(), HomeViewModel › reloadKey, HomeView › body | bağlar(okur+yazar): HomeView › body | YAZAR: HomeViewModelTests (test)
    var nearMe = false // "Yakınımdakiler" anahtarı: true iken liste telefonun konumuna göre yakından uzağa sıralanır

    // ⮕ ZİNCİR: Views/HomeView: if viewModel.isShipper { Yük Veren ekranı } else { Taşımacı ekranı } ve toolbar düğmeleri | kaynak: user.role
    // ⮕ KULLANIM [isShipper]: okur: HomeViewModel › load(), HomeView › body
    var isShipper: Bool { user.role == "Shipper" } // türetilmiş değer: rol kararı tek yerde (ekran ve mantık aynı tanımı kullanır)

    init(user: LoginUser,
         listingService: ListingServicing = ListingService(),
         offerService: OfferServicing = OfferService(),
         notificationService: NotificationServicing = NotificationService(), // varsayılan parametre [SWIFT]: verilmezse gerçek servis, testte sahtesi
         push: PushRegistering = PushManager.shared,
         cityService: CityServicing = CityService(),
         session: SessionSigningOut = AuthSession.shared,
         location: LocationProviding = LocationManager()) {
        self.user = user
        self.listingService = listingService
        self.offerService = offerService
        self.notificationService = notificationService
        self.push = push
        self.cityService = cityService
        self.session = session
        self.location = location
    }

    // ⮕ ZİNCİR: Views/HomeView: "Konum izni kapalı" + "Ayarları aç" satırı yalnız nearMe açıkken ve izin reddedilmişse görünür | kaynak: Models/Location/LocationManager.isDenied
    // ⮕ KULLANIM [isLocationDenied]: okur: HomeView › body, HomeViewModelTests (test)
    var isLocationDenied: Bool { nearMe && location.isDenied }
    // ⮕ ZİNCİR: Views/HomeView: konum alınamadı gibi kırmızı küçük yazı (yalnız nearMe açıkken ve izin reddedilmemişse) | kaynak: Models/Location/LocationManager.errorMessage
    // ⮕ KULLANIM [locationError]: okur: HomeView › body, HomeViewModelTests (test)
    var locationError: String? { nearMe && !location.isDenied ? location.errorMessage : nil }

    // nearMeChanged: "Yakınımdakiler" anahtarı değişince çağrılır | açıldıysa konum motoruna "izin sor ve konumu bul" der
    // izin ya da konum gelene kadar liste eskisi gibi kalır, konum gelince reloadKey değişir ve load() listeyi sıralı yeniler
    // ⮕ ZİNCİR: Views/HomeView: Toggle üzerindeki .onChange(of: viewModel.nearMe) → viewModel.nearMeChanged(to:) → Models/Location/LocationManager.request() (izin penceresi / konum)
    // ⮕ KULLANIM [nearMeChanged]: çağırır: HomeView › body, HomeViewModelTests (test)
    func nearMeChanged(to isOn: Bool) {
        if isOn { location.request() }
    }

    // signOut: "Çıkış Yap" düğmesi | önce yerel oturum silinir (Keychain + bellek), sonra sunucuya haber verilir (jeton orada da iptal edilsin)
    // ⮕ ZİNCİR: Views/HomeView: Button("Çıkış Yap") { Task { await viewModel.signOut(); dismiss() } } → Models/Networking/AuthSession.signOut() → POST /api/v1/auth/logout
    // ⮕ KULLANIM [signOut]: çağırır: HomeViewModel › signOut(), HomeView › body, HomeViewModelTests (test)
    func signOut() async { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz)
        await push.unregister() // ÖNCE push adresi silinir (istek jeton ister), SONRA oturum kapanır
        await session.signOut() // await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }

    // load: ana sayfanın verisini API'den çekip durum değişkenlerine yazar
    // Konum, ViewModel'in kendi `location`ından okunur: yalnız "Yakınımdakiler" AÇIKSA ve konum BULUNMUŞSA API'ye gönderilir
    // ÇAĞIRAN: View → .task(id:) (ekran açılınca/filtre değişince/konum bulununca) ve .refreshable (aşağı çekince)
    // ⮕ ZİNCİR: Views/HomeView: .task(id: reloadKey) ve List'lerdeki .refreshable | Yük Veren → ListingService.myListings() | Taşımacı → ListingService.openListings(...) + CityService.cities() + OfferService.unseenCount()
    // ⮕ KULLANIM [load]: çağırır: HomeView › body, HomeViewModelTests (test)
    // loadUnread: zil sayısını tazeler | try? [SWIFT]: hata olursa nil (rozet için hata gösterilmez, eski sayı kalır)
    // ÇAĞIRAN: HomeView .onAppear (ekran her göründüğünde, bildirim listesinden dönüşte de) | API: GET /api/v1/notifications/unread-count
    func loadUnread() async {
        if let count = try? await notificationService.unreadCount() {
            unreadNotifications = count
            push.setBadge(count) // uygulama simgesindeki sayı zil ile aynı kalsın
        }
    }

    // enablePush: giriş yapılmış ana ekran açılınca | izin penceresi + Apple kaydı + adresi sunucuya gönderme ⮕ PushManager.enable()
    func enablePush() async { await push.enable() }

    func load() async {
        listError = nil // eski hata yazısını temizle | NEDEN: load her yenilemede çalışır; temizlemezsek bir kez çıkan hata sonraki BAŞARILI yüklemeden sonra da ekranda kalırdı
        do {
            if isShipper { // VERİ kararı: rol hangi ucu çağıracağımızı belirler
                listings = try await listingService.myListings() // GET /api/v1/listings/mine
            } else {
                let result = try await fetchOpen(page: 1) // GET /api/v1/listings?page=1&...
                listings = result.items // liste baştan kurulur
                page = 1
                totalCount = result.totalCount
                if cities.isEmpty { cities = (try? await cityService.cities()) ?? [] } // il listesi yalnız bir kez yüklenir | try?: hata olursa nil | ?? []: nil ise boş liste | try? [SWIFT]: hata olursa çökme, nil ver
                
                unseenCount = try await offerService.unseenCount() // rozet sayısı
            }
        } catch {
            if let message = error.userMessage { listError = message } // iptal ise (nil) yazı gösterilmez
        }
    }

    // loadMore: listenin sonuna gelince SONRAKİ sayfayı çekip listeye ekler
    // ÇAĞIRAN: Views/HomeView son satır .onAppear | guard: Yük Veren'de sayfa yok, son sayfada ya da zaten yüklenirken istek atılmaz
    // ZİNCİR: fetchOpen(page+1) → ListingService.openListings → GET /api/v1/listings?page=2&... → Page<Listing>
    func loadMore() async {
        guard !isShipper, hasMore, !isLoadingMore else { return } // guard [SWIFT]: şart sağlanmazsa erken çık
        isLoadingMore = true
        defer { isLoadingMore = false } // defer [SWIFT]: fonksiyon nasıl biterse bitsin (başarı/hata) en sonda çalışır
        do {
            let result = try await fetchOpen(page: page + 1)
            let known = Set(listings.map(\.id)) // Set [SWIFT]: tekrarsız küme | sayfalar kayarsa aynı ilan iki kez gelmesin
            listings += result.items.filter { !known.contains($0.id) } // += sona ekler | filter [SWIFT]: şartı sağlayanları tutar
            page += 1
            totalCount = result.totalCount
        } catch {
            if let message = error.userMessage { listError = message } // liste silinmez, yalnız hata yazılır
        }
    }

    // fetchOpen: load ve loadMore'un ORTAK kısmı | filtre paketini + (nearMe açıksa) konumu kurup servisi çağırır
    // BAĞLANTI: OpenListingsFilter (Models/Listings) | location (LocationProviding) | ListingServicing.openListings
    private func fetchOpen(page: Int) async throws -> Page<Listing> {
        let lat = nearMe ? location.latitude : nil // konum yoksa nil: sıralama en yeni
        let lon = nearMe ? location.longitude : nil
        return try await listingService.openListings(filter: filter, page: page, lat: lat, lon: lon)
    }

    // cityFilterChanged: il Picker'ı değişince çağrılır | ilçe seçimi sıfırlanır ve yeni ilin ilçeleri çekilir
    // NEDEN sıfırlama: eski ilin ilçesi yeni ile ait değildir, kalırsa yanlış filtre gider
    // ⮕ ZİNCİR: Views/HomeView: il Picker'ındaki .onChange(of: viewModel.filterCityId) → Task { await viewModel.cityFilterChanged(to:) } | CityService.districts(cityId:)
    // ⮕ KULLANIM [cityFilterChanged]: çağırır: HomeView › body, HomeViewModelTests (test)
    func cityFilterChanged(to cityId: Int) async {
        filter.fromDistrictId = 0 // eski ilin ilçesi sıfırlanır
        filterDistricts = []
        guard cityId != 0 else { return } // "Tüm İller"e dönüldüyse çekecek ilçe yok | guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
        filterDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // reloadKey: ekranın .task(id:) değeri | bu yazı değişince liste yeniden yüklenir (filtre, anahtar ya da konum değişti)
    // ⮕ ZİNCİR: Views/HomeView: .task(id: viewModel.reloadKey) — bu yazı değişince (filtre, anahtar, konum) SwiftUI task'ı yeniden çalıştırır → load()
    // ⮕ KULLANIM [reloadKey]: okur: HomeView › body, HomeViewModelTests (test)
    var reloadKey: String {
        "\(filter)-\(nearMe)-\(location.latitude.map { String($0) } ?? "-"),\(location.longitude.map { String($0) } ?? "-")"
    }
}
