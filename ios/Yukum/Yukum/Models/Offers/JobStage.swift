//
//  JobStage.swift
//  Yukum
//

import Foundation

// Kabul edilmiş işin aşaması | API'den "NotStarted" / "PickedUp" / "InTransit" / "Delivered" yazısı gelir
// enum [SWIFT]: sabit seçenek listesi | String: her seçeneğin API'deki yazı karşılığı var (rawValue) → JobStage(rawValue: "PickedUp") = .pickedUp
// Sıra yalnız ileri: Taşımacı advanceTitle düğmesine basar → ViewModel OfferService.advance çağırır → sunucu bir sonraki aşamaya geçirir
// BAĞLANTI: MyOffersViewModel (Taşımacı: düğme) · OldOffersViewModel (Yük Veren: izleme) · ChatContext (İşi bitir yalnız .delivered'da)
enum JobStage: String {
    case notStarted = "NotStarted"
    case pickedUp = "PickedUp"
    case inTransit = "InTransit"
    case delivered = "Delivered"

    // title: ekranda görünen aşama adı
    var title: String {
        switch self { // switch [SWIFT]: değere göre dallanır | enum'da tüm durumlar yazılmak zorunda (derleyici eksiği yakalar)
        case .notStarted: "Yük bekleniyor"
        case .pickedUp: "Yük alındı"
        case .inTransit: "Yolda"
        case .delivered: "Teslim edildi"
        }
    }

    // advanceTitle: bir SONRAKİ aşamaya geçiren düğmenin yazısı | nil = ilerletilecek aşama kalmadı (düğme çizilmez)
    var advanceTitle: String? { // String?: nil olabilir
        switch self {
        case .notStarted: "Yükü aldım"
        case .pickedUp: "Yola çıktım"
        case .inTransit: "Teslim ettim"
        case .delivered: nil
        }
    }
}
