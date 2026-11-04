//
//  ListingServicing.swift
//  Yukum
//

import Foundation

// BU DOSYA: servislerin "ne yapabildiğini" anlatan SÖZLEŞMELER (protocol).
// NEDEN: ViewModel'ler somut servise (ListingService) değil, sözleşmeye (ListingServicing) bağlı olur.
//   → gerçek uygulamada gerçek servis verilir, TESTTE sahte servis verilir (internet/sunucu gerekmez). Buna BAĞIMLILIK ENJEKSİYONU (Dependency Injection) denir.
// protocol [SWIFT]: "bu fonksiyonlara sahip olan her şey bu sözleşmeyi karşılar" | adlandırma: yaptığı işin sıfat hâli (...Servicing)
// BAĞLANTI: ViewModels/*.swift sözleşmeleri kullanır | gerçek servisler Services/*Service.swift (aşağıdaki extension'lar onları sözleşmeye bağlar) | sahte servisler YukumTests/Support/

protocol ListingServicing {
    func create(_ body: CreateListingRequest) async throws -> ListingResponse
    func myListings() async throws -> [Listing]
    func openListings(fromCityId: Int, fromDistrictId: Int, lat: Double?, lon: Double?) async throws -> [Listing]
    func cancel(listingId: String) async throws
}
