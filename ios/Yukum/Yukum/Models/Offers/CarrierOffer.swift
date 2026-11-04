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
// └──────────────────────────────────────────────────────────────────────

// CarrierOffer: Taşımacı'nın "Tekliflerim" listesindeki TEK SATIRIN kalıbı.
// NE İŞE YARAR: API'den gelen JSON'daki her teklif bu struct'a çevrilir (Decodable) | alan adları API'deki ile BİREBİR aynı olmalı, yoksa okuma hatası verir
// NEREDE KULLANILIR: Services/OfferService.swift → myOffers() bu struct'ın listesini döner → Views/MyOffersView.swift listeyi ekrana çizer
// ⮕ KULLANIM [CarrierOffer]: kullanır: ChatContext › forCarrier(), MyOffersViewModel › offers, MyOffersViewModel › pendingOffers, MyOffersViewModel › historyOffers, MyOffersViewModel › canHide(), MyOffersViewModel › canChat() … +7
struct CarrierOffer: Decodable, Identifiable { // Decodable [SWIFT]: JSON'dan üretilebilir | Identifiable [SWIFT]: benzersiz id'si var, List'te "id:" yazmak gerekmez
    // ⮕ KULLANIM [id]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let id: String // teklif numarası (GUID, yazı gelir) | Identifiable bunu kullanır | silme isteğine (hide) bu gider
    // ⮕ KULLANIM [listingTitle]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let listingTitle: String // teklif verdiğimiz ilanın başlığı | satırın üst yazısı
    // ⮕ KULLANIM [fromCityName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fromCityName: String // ilanın kalkış ili | rota yazısı için
    // ⮕ KULLANIM [toCityName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let toCityName: String // ilanın varış ili | rota yazısı için
    // ⮕ KULLANIM [amount]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let amount: Double // verdiğimiz teklif tutarı | Double: API 48000.0 gibi ondalıklı gönderir | ekranda Int(amount) ile 48000 yazılır
    // ⮕ KULLANIM [status]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let status: String // teklifin durumu: "Pending" (beklemede) / "Accepted" (kabul) / "Rejected" (red) | switch ile renkli yazıya çevrilir | yalnız karar verilmişler (Pending değil) silinebilir
    // ⮕ KULLANIM [isNew]: okur: MyOffersView › offerRow(), MyOffersViewModelTests (test)
    let isNew: Bool // Bool: true/false | true = Yük Veren karar verdi (kabul/red) AMA Taşımacı henüz Tekliflerim ekranını açıp görmedi | backend: Offer.CarrierSeen=false ve karar verilmiş
    //NE İŞE YARAR: push bildirim yerine uygulama içi "Yeni" rozeti | NEREDE: MyOffersView'da satırdaki kırmızı hap | ekran açılınca markSeen() false yapar
    
    // ⮕ KULLANIM [fromDistrictName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let fromDistrictName: String // kalkış ilçesi | NE İŞE YARAR: rotada il yanında ilçeyi göstermek | NEREDE: MyOffersView rota satırı | API'deki "fromDistrictName" ile aynı ad
    // ⮕ KULLANIM [toDistrictName]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let toDistrictName: String // varış ilçesi | aynı amaçla
    // ⮕ KULLANIM [shipperName]: okur: ChatContext › forCarrier(), MyOffersView › offerRow()
    let shipperName: String // ilanı açan Yük Veren'in adı | NE İŞE YARAR: Taşımacı teklifin kimden geldiğini/kime verildiğini görsün | NEREDE: MyOffersView "Yük Veren:" satırı
    // ⮕ KULLANIM [weightKg]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let weightKg: Int // yükün ağırlığı (kg) | NE İŞE YARAR: teklif geçmişinde ilanı hatırlatan detay | NEREDE: MyOffersView detay satırı
    // ⮕ KULLANIM [pickupDate]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let pickupDate: String // yükleme tarihi, "2026-11-05" yazısı gelir | NEREDE: MyOffersView detay satırı

}
