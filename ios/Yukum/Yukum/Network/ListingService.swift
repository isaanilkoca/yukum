//
//  ListingService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 30.10.2026.
//

import Foundation // [SWIFT] ağ araçları (URL, JSON) bu kütüphanede

// BU DOSYA: ilan uçlarıyla konuşur. İsteğin kendisi (zarf, jeton, 401'de otomatik yenileme, hata çevirme) Network/APIClient.swift'te;
// burada yalnız "hangi adres, hangi paket, ne döner" yazılır → her fonksiyon tek satır.
// BAĞLANTI: View/CreateListingView.swift, View/HomeView.swift, View/ListingOffersView.swift çağırır | paket kalıpları: Network/ListingRequest.swift | API: backend ListingsController
struct ListingService { // struct [SWIFT]: alan+fonksiyon taşıyan kalıp | ListingService [BİZİM] ad

    private let api = APIClient.shared // tüm istekler bu kapıdan geçer

    // create: ilan açar | async: cevabı bekler | throws: hata fırlatabilir | -> ListingResponse: başarıda oluşan ilanı döner
    // _ body: dışarıdan CreateListingRequest alır (Network/ListingRequest.swift) | ÇAĞIRAN: View/CreateListingView.swift "İlanı Yayınla" düğmesi
    // API: POST /api/v1/listings (yalnız Yük Veren) | body: JSON'a çevrilip gövdeye konur
    func create(_ body: CreateListingRequest) async throws -> ListingResponse {
        try await api.send(.post, "/api/v1/listings", body: body, fallback: "İlan açılamadı.") // fallback: sunucu açıklama vermezse gösterilecek yazı
    }

    // myListings: Yük Veren'in kendi AÇIK ilanları | -> [Listing]: ilan listesi (kalıbı: Network/ListingRequest.swift)
    // ÇAĞIRAN: View/HomeView.swift (Yük Veren için, ekran her göründüğünde) | API: GET /api/v1/listings/mine
    func myListings() async throws -> [Listing] {
        try await api.send(.get, "/api/v1/listings/mine", fallback: "İlanlar yüklenemedi.") // GET: veri iste, gövde yok
    }

    // openListings: tüm açık ilanlar (Taşımacı anasayfası) | İSTEĞE BAĞLI FİLTRE: kalkış ili ve ilçesi, ve konum
    // fromCityId / fromDistrictId: 0 = "Tümü", filtre uygulanmaz | = 0: varsayılan değer, çağıran yazmazsa 0 sayılır
    // lat / lon: Taşımacı'nın konumu | Double? = boş olabilir, nil ise konum gönderilmez
    // NE İŞE YARAR: süzme ve mesafe sıralamasını SUNUCU yapar (SQL WHERE, Haversine) | telefon tüm ilanları çekip kendisi süzmez, çünkü ilan sayısı büyüyünce yavaşlar ve gereksiz veri taşır | konum sunucuda SAKLANMAZ
    // ÇAĞIRAN: View/HomeView.swift (Taşımacı) | API: GET /api/v1/listings?fromCityId=33&fromDistrictId=12&lat=36.8&lon=34.6
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
    // ÇAĞIRAN: View/ListingOffersView.swift sağ üst "Kaldır" | API: POST /api/v1/listings/{id}/cancel (gövdesiz, cevap 204)
    func cancel(listingId: String) async throws {
        try await api.sendNoContent(.post, "/api/v1/listings/\(listingId)/cancel", fallback: "İlan kaldırılamadı.") // sendNoContent: cevapta veri beklenmez
    }
}
