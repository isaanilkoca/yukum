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
struct ListingOffer: Decodable, Identifiable { // Identifiable [SWIFT]: benzersiz id'si var, List'te id: yazmak gerekmez
    let id: String // teklif numarası (GUID yazı gelir) | kabul/reddet uçlarına bu gider
    let carrierName: String // teklifi veren taşımacının adı
    let amount: Double // tutar | API 48000.0 gönderir
    let note: String? // isteğe bağlı not, yoksa nil
    let status: String // "Pending" / "Accepted" / "Rejected" (API durumu yazı olarak gönderir)
}

