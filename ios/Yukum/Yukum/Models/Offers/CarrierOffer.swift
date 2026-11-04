//
//  CarrierOffer.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: CarrierOffer (Taşımacı'nın teklifi) ─────────────────────────
// │ MODEL     : Taşımacı'nın verdiği tek teklif: ilan özeti, tutar, durum, "Yeni" rozeti bilgisi
// │ ÜRETEN    : Services/OfferService.myOffers ← GET /api/v1/offers/mine
// │ SAKLAYAN  : ViewModels/MyOffersViewModel.offers (pendingOffers / historyOffers ile iki bölüme ayrılır) → Views/MyOffersView
// │ SOHBET    : ViewModels/ChatContext.forCarrier(_:)
// │ HAZIR (Swift/Apple) [SWIFT] : Decodable, Identifiable, String, Int, Bool, Double
// │ BİZİM (bizim yazdığımız) [BİZİM] : türler: CarrierOffer | değişken/durumlar: id, listingTitle, fromCityName, toCityName, amount, status, isNew, fromDistrictName, toDistrictName, shipperName …
// └──────────────────────────────────────────────────────────────────────

// CarrierOffer: Taşımacı'nın "Tekliflerim" listesindeki TEK SATIRIN kalıbı.
// NE İŞE YARAR: API'den gelen JSON'daki her teklif bu struct'a çevrilir (Decodable) | alan adları API'deki ile BİREBİR aynı olmalı, yoksa okuma hatası verir
// NEREDE KULLANILIR: Services/OfferService.swift → myOffers() bu struct'ın listesini döner → Views/MyOffersView.swift listeyi ekrana çizer
struct CarrierOffer: Decodable, Identifiable { // Decodable [SWIFT]: JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var, List'te "id:" yazmak gerekmez
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
