//
//  UnseenCount.swift
//  Yukum
//

import Foundation

// ┌─ BAĞLANTI HARİTASI: UnseenCount (bildirim sayısı) ───────────────────────────────
// │ MODEL     : "Kaç tane görmediğin karar var" cevabı: {"count": 3}
// │ ÜRETEN    : Features/Offers/OfferService.unseenCount ← GET /api/v1/offers/mine/unseen-count (servis yalnız .count sayısını geri verir)
// │ SAKLAYAN  : Features/Listings/HomeViewModel.unseenCount → Features/Listings/HomeView: sağ üst kutu ikonundaki kırmızı rozet
// └──────────────────────────────────────────────────────────────────────

// UnseenCount: "kaç tane görülmemiş karar var" cevabının kalıbı. API {"count": 3} gönderir.
// NE İŞE YARAR: tek bir sayıyı struct içinde almak (API her zaman nesne döner, çıplak sayı değil)
// NEREDE KULLANILIR: Features/Offers/OfferService.swift → unseenCount() bunu çevirip yalnız .count'u döner → HomeView'daki kutu ikonunun rozeti
// ⮕ KULLANIM [UnseenCount]: kullanır: OfferService › unseenCount()
struct UnseenCount: Decodable { // Decodable: JSON → struct | Decodable [SWIFT]: JSON'dan bu türde değer üretilebilir
    // ⮕ KULLANIM [count]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    let count: Int // görülmemiş karar sayısı | 0 ise rozet çizilmez
}
