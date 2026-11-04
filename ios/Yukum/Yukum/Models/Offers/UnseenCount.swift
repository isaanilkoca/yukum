//
//  UnseenCount.swift
//  Yukum
//

import Foundation

// UnseenCount: "kaç tane görülmemiş karar var" cevabının kalıbı. API {"count": 3} gönderir.
// NE İŞE YARAR: tek bir sayıyı struct içinde almak (API her zaman nesne döner, çıplak sayı değil)
// NEREDE KULLANILIR: Services/OfferService.swift → unseenCount() bunu çevirip yalnız .count'u döner → HomeView'daki kutu ikonunun rozeti
struct UnseenCount: Decodable { // Decodable: JSON → struct
    let count: Int // görülmemiş karar sayısı | 0 ise rozet çizilmez
}
