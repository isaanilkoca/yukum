//
//  ListingOffer.swift
//  Yukum
//

import Foundation

// Hashable [SWIFT]: "birbirinden ayırt edilebilir, karşılaştırılabilir" | .navigationDestination(item:) seçili öğeyi bununla takip eder | alanlar hazır tiplerden olduğu için kod yazmak gerekmez
// Hashable [SWIFT]: "bu öğe tek başına ayırt edilebilir ve karşılaştırılabilir" demek | NEDEN: .navigationDestination(item:) seçili öğeyi (chatOffer) bununla takip eder | tüm alanlar hazır tipler (String, Double...) olduğu için ek kod yazmak gerekmez
struct ListingOffer: Decodable, Identifiable , Hashable { // Identifiable [SWIFT]: benzersiz id'si var, List'te id: yazmak gerekmez
    let id: String // teklif numarası (GUID yazı gelir) | kabul/reddet uçlarına bu gider
    let carrierName: String // teklifi veren taşımacının adı
    let amount: Double // tutar | API 48000.0 gönderir
    let note: String? // isteğe bağlı not, yoksa nil
    let status: String // "Pending" / "Accepted" / "Rejected" (API durumu yazı olarak gönderir)
}
