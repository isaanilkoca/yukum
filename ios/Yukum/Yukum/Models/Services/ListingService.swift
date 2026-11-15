//
//  ListingService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 30.10.2026.
//

import Foundation // [SWIFT] ağ araçları (URL, JSON) bu kütüphanede

// ┌─ BAĞLANTI HARİTASI: ListingService (ilan uçları) ────────────────────────────────
// │ ÇAĞIRAN   : ViewModels/HomeViewModel (myListings, openListings) | CreateListingViewModel (create) | ListingOffersViewModel (cancel) — Models/Services/Protocols/ListingServicing sözleşmesi üzerinden
// │ KULLANIR  : Models/Networking/APIClient (tek kapı) | MODEL: Listing, CreateListingRequest, ListingResponse
// │ API       : backend ListingsController: POST/GET /api/v1/listings, GET /listings/mine, POST /listings/{id}/cancel
// │ SAHTESİ   : YukumTests/Support/FakeListingService.swift
// └──────────────────────────────────────────────────────────────────────

// BU DOSYA: ilan uçlarıyla konuşur. İsteğin kendisi (zarf, jeton, 401'de otomatik yenileme, hata çevirme) Models/Networking/APIClient.swift'te;
// burada yalnız "hangi adres, hangi paket, ne döner" yazılır → her fonksiyon tek satır.
// BAĞLANTI: Views/CreateListingView.swift, Views/HomeView.swift, Views/ListingOffersView.swift çağırır | paket kalıpları: Models/Listings/ | API: backend ListingsController
// ⮕ KULLANIM [ListingService]: kullanır: CreateListingViewModel › init(), HomeViewModel › init(), ListingOffersViewModel › init()
struct ListingService { // struct [SWIFT]: alan+fonksiyon taşıyan kalıp | ListingService [BİZİM] ad

    // ⮕ KULLANIM [api]: okur: ListingService › create(), ListingService › myListings(), ListingService › openListings(), ListingService › cancel()
    private let api: APIClient // tüm istekler bu kapıdan geçer
    // init(api:): varsayılan ortak istemci (uygulama değişmez) | testte sahte ağlı istemci verilir → hangi adrese hangi istek gittiği sınanır (YukumTests/Networking/ServiceContractTests)
    init(api: APIClient = .shared) { self.api = api }

    // create: ilan açar | async: cevabı bekler | throws: hata fırlatabilir | -> ListingResponse: başarıda oluşan ilanı döner
    // _ body: dışarıdan CreateListingRequest alır (Models/Listings/) | ÇAĞIRAN: Views/CreateListingView.swift "İlanı Yayınla" düğmesi
    // API: POST /api/v1/listings (yalnız Yük Veren) | body: JSON'a çevrilip gövdeye konur
    // ⮕ ZİNCİR: ViewModels/CreateListingViewModel.submit() ← Views/CreateListingView "İlanı Yayınla" | API: POST /api/v1/listings | GİDEN: CreateListingRequest | DÖNEN: ListingResponse
    // ⮕ KULLANIM [create]: çağırır: CreateListingViewModel › submit()
    func create(_ body: CreateListingRequest) async throws -> ListingResponse { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
        try await api.send(.post, "/api/v1/listings", body: body, fallback: "İlan açılamadı.") // fallback: sunucu açıklama vermezse gösterilecek yazı | await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }
    
    // PUT = kaydı bütünüyle değiştir (POST yeni kayıt açar) | \(listingId) adrese id'yi koyar
    // Sunucu hatası (404 başkasının, 409 kabul edilmiş, 400 doğrulama) APIClient'ta APIError olur, mesaj Türkçe gelir
    // ZİNCİR: CreateListingViewModel.submit() → PUT /api/v1/listings/{id} → ListingResponse
    func update(listingId: String, _ body: CreateListingRequest) async throws -> ListingResponse {
        try await api.send(.put, "/api/v1/listings/\(listingId)", body: body, fallback: "İlan güncellenemedi.")
    }
    
    

    // myListings: Yük Veren'in kendi AÇIK ilanları | -> [Listing]: ilan listesi (kalıbı: Models/Listings/)
    // ÇAĞIRAN: Views/HomeView.swift (Yük Veren için, ekran her göründüğünde) | API: GET /api/v1/listings/mine
    // ⮕ ZİNCİR: ViewModels/HomeViewModel.load() (Yük Veren) ← Views/HomeView .task/.refreshable | API: GET /api/v1/listings/mine | DÖNEN: [Listing]
    // ⮕ KULLANIM [myListings]: çağırır: HomeViewModel › load()
    func myListings() async throws -> [Listing] {
        try await api.send(.get, "/api/v1/listings/mine", fallback: "İlanlar yüklenemedi.") // GET: veri iste, gövde yok
    }

    // allMyListings (15 Kasım, 8. adım): açık + atanmış + tamamlanmış + kaldırılmış, her biri status alanıyla
    // ÇAĞIRAN: MyListingsViewModel (profil > İlanlarım) | API: GET /api/v1/listings/mine?all=true → GetMyListingsHandler (IncludeClosed)
    func allMyListings() async throws -> [Listing] {
        try await api.send(.get, "/api/v1/listings/mine", query: [URLQueryItem(name: "all", value: "true")], fallback: "İlanlar yüklenemedi.")
    }

    // openListings: Taşımacı anasayfasının açık ilan listesinin BİR SAYFASI | süzme, sıralama, sayfalamayı SUNUCU yapar, telefon hepsini çekmez
    // ÇAĞIRAN: HomeViewModel.load() | API: GET /api/v1/listings?page=1&pageSize=20&... | DÖNEN: Page<Listing>
    // lat / lon: Taşımacı'nın konumu (Double? = nil ise gönderilmez) | konum sunucuda SAKLANMAZ
    func openListings(filter: OpenListingsFilter, page: Int, lat: Double? = nil, lon: Double? = nil) async throws -> Page<Listing> {
        let items = filter.queryItems(page: page, pageSize: Self.pageSize, lat: lat, lon: lon) // adresin ?'ten sonrası
        // send<Response>: JSON'u Response türüne çevirir; tür dönüş tipinden anlaşılır (Page<Listing>)
        return try await api.send(.get, "/api/v1/listings", query: items, fallback: "İlanlar yüklenemedi.")
    }

    static let pageSize = 20 // static [SWIFT]: türe ait sabit | API en çok 50 kabul eder

    // setFavorite: kalbe basınca | PUT = "favori olsun", DELETE = "favori olmasın" | ikisi de tekrar çağrılabilir (sunucu idempotent), cevap 204 (gövde yok)
    // HTTPMethod seçimi if/else: isFavorite true ise .put, değilse .delete | `condition ? a : b` [SWIFT]: kısa if
    func setFavorite(listingId: String, isFavorite: Bool) async throws {
        try await api.sendNoContent(isFavorite ? .put : .delete, "/api/v1/listings/\(listingId)/favorite", fallback: "Favori güncellenemedi.")
    }

    // favorites: GET /api/v1/listings/favorites → [Listing] (isFavorite hepsinde true)
    func favorites() async throws -> [Listing] {
        try await api.send(.get, "/api/v1/listings/favorites", fallback: "Favoriler yüklenemedi.")
    }

    // recordView: görüntülenme kaydı | sunucu aynı kişiyi günde bir kez sayar | cevap 204
    func recordView(listingId: String) async throws {
        try await api.sendNoContent(.post, "/api/v1/listings/\(listingId)/view", fallback: "Görüntülenme yazılamadı.")
    }

    // stats: GET /api/v1/listings/{id}/stats → ListingStats (yalnız ilan sahibi; başkasınınsa 404)
    func stats(listingId: String) async throws -> ListingStats {
        try await api.send(.get, "/api/v1/listings/\(listingId)/stats", fallback: "Sayılar yüklenemedi.")
    }

    // priceReference: aynı rota + araç tipi için son tamamlanan işlerin medyan tutarı
    // API: GET /api/v1/price-reference?fromCityId=33&toCityId=34&vehicleType=Truck | DÖNEN: PriceReference (medianAmount boş olabilir)
    // URLQueryItem [SWIFT, Foundation]: adresin ?'ten sonraki "ad=değer" çifti | String(Int): sayıdan yazı
    func priceReference(fromCityId: Int, toCityId: Int, vehicleType: String) async throws -> PriceReference {
        let items = [URLQueryItem(name: "fromCityId", value: String(fromCityId)),
                     URLQueryItem(name: "toCityId", value: String(toCityId)),
                     URLQueryItem(name: "vehicleType", value: vehicleType)]
        return try await api.send(.get, "/api/v1/price-reference", query: items, fallback: "Emsal fiyat yüklenemedi.")
    }

    // cancel: ilanı yayından kaldırır (yalnız ilanın sahibi Yük Veren)
    // NE İŞE YARAR: ilan "Kaldırıldı" olur, bekleyen (ve kabul edilmiş) teklifler iptal olur, Taşımacılar Tekliflerim'de "İlan kaldırıldı" görür, sohbet kilitlenir
    // ÇAĞIRAN: Views/ListingOffersView.swift sağ üst "Kaldır" | API: POST /api/v1/listings/{id}/cancel (gövdesiz, cevap 204)
    // ⮕ ZİNCİR: ViewModels/ListingOffersViewModel.cancelListing() ← Views/ListingOffersView alert "Yayından Kaldır" | API: POST /api/v1/listings/{id}/cancel | DÖNEN: yok (204)
    // ⮕ KULLANIM [cancel]: çağırır: ListingOffersViewModel › cancelListing(), ChatViewModelTests (test)
    func cancel(listingId: String) async throws {
        try await api.sendNoContent(.post, "/api/v1/listings/\(listingId)/cancel", fallback: "İlan kaldırılamadı.") // sendNoContent: cevapta veri beklenmez
    }
}


// ListingService, kendi sözleşmesini karşılar (Services/Protocols/): ViewModel'ler somut sınıfa değil sözleşmeye bağlıdır, testte sahtesi verilir
// Gerçek servisler zaten bu fonksiyonlara sahip; "sen de bu sözleşmeyi karşılıyorsun" demek için boş extension yeter
extension ListingService: ListingServicing {} // extension [SWIFT]: mevcut türe sonradan özellik/uyum ekler

