//
//  OfferRequest.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import Foundation

// BU DOSYA: teklif paketlerinin kalıpları. Gönderilecek paket + gelen cevap.
// BAĞLANTI: Network/OfferService.swift bu kalıpları kullanır | API: POST /api/v1/listings/{id}/offers


// Giden paket. Encodable [SWIFT]: struct → JSON'a çevrilebilir.
// FONKSİYON ROLÜ: GİDEN paket kalıbı | ListingDetailView düğmesi doldurur, OfferService.create JSON'a çevirip API'ye yollar
struct CreatOfferRequest : Encodable {
    
    let amount: Int // teklif tutarı TL | API'deki "amount" ile aynı ad olmalı    l
    let note: String? // isteğe bağlı not | ?: boş olabilir, nil ise JSON'a yazılmaz
    
}

// Gelen cevap. Decodable [SWIFT]: JSON → struct'a çevrilebilir. Yalnız ihtiyacımız olan alanı aldık.
// FONKSİYON ROLÜ: GELEN cevap kalıbı | OfferService.create API cevabını (JSON) buna çevirip ListingDetailView'a döner
struct offerResponse : Decodable {
    let amount : Double // API tutarı 1200.0 gibi ondalıklı gönderir, Int değil Double okunur
}


// Yük Veren'in gördüğü tek teklif satırı (GET /api/v1/listings/{id}/offers listesindeki her eleman).
// BAĞLANTI: OfferService.listingOffers bu struct'ın listesini döner → View/ListingOffersView.swift'te liste olarak gösterilir

// Hashable [SWIFT]: "birbirinden ayırt edilebilir, karşılaştırılabilir" | .navigationDestination(item:) seçili öğeyi bununla takip eder | alanlar hazır tiplerden olduğu için kod yazmak gerekmez
// Hashable [SWIFT]: "bu öğe tek başına ayırt edilebilir ve karşılaştırılabilir" demek | NEDEN: .navigationDestination(item:) seçili öğeyi (chatOffer) bununla takip eder | tüm alanlar hazır tipler (String, Double...) olduğu için ek kod yazmak gerekmez
struct ListingOffer: Decodable, Identifiable , Hashable { // Identifiable [SWIFT]: benzersiz id'si var, List'te id: yazmak gerekmez
    let id: String // teklif numarası (GUID yazı gelir) | kabul/reddet uçlarına bu gider
    let carrierName: String // teklifi veren taşımacının adı
    let amount: Double // tutar | API 48000.0 gönderir
    let note: String? // isteğe bağlı not, yoksa nil
    let status: String // "Pending" / "Accepted" / "Rejected" (API durumu yazı olarak gönderir)
}


// CarrierOffer: Taşımacı'nın "Tekliflerim" listesindeki TEK SATIRIN kalıbı.
// NE İŞE YARAR: API'den gelen JSON'daki her teklif bu struct'a çevrilir (Decodable) | alan adları API'deki ile BİREBİR aynı olmalı, yoksa okuma hatası verir
// NEREDE KULLANILIR: Network/OfferService.swift → myOffers() bu struct'ın listesini döner → View/MyOffersView.swift listeyi ekrana çizer
// Hashable: aynı sebep | MyOffersView'daki chatOffer + .navigationDestination(item:) için gerekli
struct CarrierOffer: Decodable, Identifiable,Hashable { // Decodable [SWIFT]: JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var, List'te "id:" yazmak gerekmez
    let id: String // teklif numarası (GUID, yazı gelir) | Identifiable bunu kullanır | silme isteğine (hide) bu gider
    let listingTitle: String // teklif verdiğimiz ilanın başlığı | satırın üst yazısı
    let fromCityName: String // ilanın kalkış ili | rota yazısı için
    let toCityName: String // ilanın varış ili | rota yazısı için
    let amount: Double // verdiğimiz teklif tutarı | Double: API 48000.0 gibi ondalıklı gönderir | ekranda Int(amount) ile 48000 yazılır
    let status: String // teklifin durumu: "Pending" (beklemede) / "Accepted" (kabul) / "Rejected" (red) | switch ile renkli yazıya çevrilir | yalnız karar verilmişler (Pending değil) silinebilir
    let isNew: Bool // Bool: true/false | true = Yük Veren karar verdi (kabul/red) AMA Taşımacı henüz Tekliflerim ekranını açıp görmedi | backend: Offer.CarrierSeen=false ve karar verilmiş
    //NE İŞE YARAR: push bildirim yerine uygulama içi "Yeni" rozeti | NEREDE: MyOffersView'da satırdaki kırmızı hap | ekran açılınca markSeen() false yapar
    
    let fromDistrictName: String // kalkış ilçesi | NE İŞE YARAR: rotada il yanında ilçeyi göstermek | NEREDE: MyOffersView rota satırı | API'deki "fromDistrictName" ile aynı ad
    let toDistrictName: String // varış ilçesi | aynı amaçla
    let shipperName: String // ilanı açan Yük Veren'in adı | NE İŞE YARAR: Taşımacı teklifin kimden geldiğini/kime verildiğini görsün | NEREDE: MyOffersView "Yük Veren:" satırı
    let weightKg: Int // yükün ağırlığı (kg) | NE İŞE YARAR: teklif geçmişinde ilanı hatırlatan detay | NEREDE: MyOffersView detay satırı
    let pickupDate: String // yükleme tarihi, "2026-11-05" yazısı gelir | NEREDE: MyOffersView detay satırı

}

// UnseenCount: "kaç tane görülmemiş karar var" cevabının kalıbı. API {"count": 3} gönderir.
// NE İŞE YARAR: tek bir sayıyı struct içinde almak (API her zaman nesne döner, çıplak sayı değil)
// NEREDE KULLANILIR: Network/OfferService.swift → unseenCount() bunu çevirip yalnız .count'u döner → HomeView'daki kutu ikonunun rozeti
struct UnseenCount: Decodable { // Decodable: JSON → struct
    let count: Int // görülmemiş karar sayısı | 0 ise rozet çizilmez
}

// ShipperHistoryOffer: Yük Veren'in "Eski teklifler" listesindeki TEK SATIRIN kalıbı (karara bağladığı bir teklif).
// NE İŞE YARAR: GET /api/v1/offers/history'deki her eleman bu struct'a çevrilir | alan adları API ile BİREBİR aynı olmalı
// NEREDE KULLANILIR: Network/OfferService.swift → shipperHistory() bu struct'ın listesini döner → View/OldOffersView.swift listeyi çizer
// Hashable: .navigationDestination(item:) seçili öğeyi (chatOffer) bununla takip eder | OldOffersView'daki Sohbet düğmesi için gerekli
struct ShipperHistoryOffer: Decodable, Identifiable, Hashable { // Decodable [SWIFT]: JSON'dan üretilir | Identifiable [SWIFT]: benzersiz id'si var
    let id: String // teklif numarası | silme isteğine (hide) bu gider
    let listingTitle: String // hangi ilana gelen teklif | satırın üst yazısı
    let fromCityName: String // kalkış ili
    let fromDistrictName: String // kalkış ilçesi
    let toCityName: String // varış ili
    let toDistrictName: String // varış ilçesi
    let weightKg: Int // yükün ağırlığı (kg)
    let pickupDate: String // yükleme tarihi "2026-11-05" yazısı
    let carrierName: String // teklifi veren Taşımacı'nın adı | NE İŞE YARAR: kime kabul/red verdiğimi hatırlamak
    let amount: Double // teklif tutarı (API 48000.0 gönderir)
    let status: String // "Accepted" (kabul ettim) / "Rejected" (reddettim) | geçmişte "Pending" olmaz, yalnız karar verilmişler gelir
}

