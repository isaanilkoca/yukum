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
    private let api = APIClient.shared // tüm istekler bu kapıdan geçer

    // create: ilan açar | async: cevabı bekler | throws: hata fırlatabilir | -> ListingResponse: başarıda oluşan ilanı döner
    // _ body: dışarıdan CreateListingRequest alır (Models/Listings/) | ÇAĞIRAN: Views/CreateListingView.swift "İlanı Yayınla" düğmesi
    // API: POST /api/v1/listings (yalnız Yük Veren) | body: JSON'a çevrilip gövdeye konur
    // ⮕ ZİNCİR: ViewModels/CreateListingViewModel.submit() ← Views/CreateListingView "İlanı Yayınla" | API: POST /api/v1/listings | GİDEN: CreateListingRequest | DÖNEN: ListingResponse
    // ⮕ KULLANIM [create]: çağırır: CreateListingViewModel › submit()
    func create(_ body: CreateListingRequest) async throws -> ListingResponse { // async [SWIFT]: bu fonksiyon beklemeli iş yapar (ekranı dondurmaz) | throws [SWIFT]: bu fonksiyon hata fırlatabilir
        try await api.send(.post, "/api/v1/listings", body: body, fallback: "İlan açılamadı.") // fallback: sunucu açıklama vermezse gösterilecek yazı | await [SWIFT]: cevap gelene kadar bekle (başka işler çalışmaya devam eder)
    }

    // myListings: Yük Veren'in kendi AÇIK ilanları | -> [Listing]: ilan listesi (kalıbı: Models/Listings/)
    // ÇAĞIRAN: Views/HomeView.swift (Yük Veren için, ekran her göründüğünde) | API: GET /api/v1/listings/mine
    // ⮕ ZİNCİR: ViewModels/HomeViewModel.load() (Yük Veren) ← Views/HomeView .task/.refreshable | API: GET /api/v1/listings/mine | DÖNEN: [Listing]
    // ⮕ KULLANIM [myListings]: çağırır: HomeViewModel › load()
    func myListings() async throws -> [Listing] {
        try await api.send(.get, "/api/v1/listings/mine", fallback: "İlanlar yüklenemedi.") // GET: veri iste, gövde yok
    }

    // openListings: tüm açık ilanlar (Taşımacı anasayfası) | İSTEĞE BAĞLI FİLTRE: kalkış ili ve ilçesi, ve konum
    // fromCityId / fromDistrictId: 0 = "Tümü", filtre uygulanmaz | = 0: varsayılan değer, çağıran yazmazsa 0 sayılır
    // lat / lon: Taşımacı'nın konumu | Double? = boş olabilir, nil ise konum gönderilmez
    // NE İŞE YARAR: süzme ve mesafe sıralamasını SUNUCU yapar (SQL WHERE, Haversine) | telefon tüm ilanları çekip kendisi süzmez, çünkü ilan sayısı büyüyünce yavaşlar ve gereksiz veri taşır | konum sunucuda SAKLANMAZ
    // ÇAĞIRAN: Views/HomeView.swift (Taşımacı) | API: GET /api/v1/listings?fromCityId=33&fromDistrictId=12&lat=36.8&lon=34.6
    // ⮕ ZİNCİR: ViewModels/HomeViewModel.load() (Taşımacı) ← Views/HomeView .task(id:)/.refreshable | API: GET /api/v1/listings?fromCityId&fromDistrictId&lat&lon | DÖNEN: [Listing]
    // ⮕ KULLANIM [openListings]: çağırır: HomeViewModel › load()
    func openListings(fromCityId: Int = 0, fromDistrictId: Int = 0, lat: Double? = nil, lon: Double? = nil) async throws -> [Listing] {
        // URLQueryItem [SWIFT]: adreste ?'ten sonraki bir "ad=değer" çifti (query string) | boş liste: filtre yoksa adrese hiçbir şey eklenmez
        var items: [URLQueryItem] = []
        if fromCityId != 0 { items.append(URLQueryItem(name: "fromCityId", value: String(fromCityId))) } // name: API'deki parametre adı, birebir aynı olmalı | String(): sayıyı yazıya çevirir
        if fromDistrictId != 0 { items.append(URLQueryItem(name: "fromDistrictId", value: String(fromDistrictId))) }
        if let lat, let lon { // API ikisini BİRLİKTE ister (yalnız biri gönderilirse 400 döner)
            items.append(URLQueryItem(name: "lat", value: String(lat)))
            items.append(URLQueryItem(name: "lon", value: String(lon)))
        }
        return try await api.send(.get, "/api/v1/listings", query: items, fallback: "İlanlar yüklenemedi.")
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
