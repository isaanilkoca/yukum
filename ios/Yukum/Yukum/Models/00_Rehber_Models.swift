//
//  00_Rehber_Models.swift — Models/ — VERİ TARAFI (MVVM'in M'si)
//  Kodu yok: klasörün ilk dosyası, ne nerede olduğunu anlatır. Son güncelleme: 15 Kasım 2026.
//

// NE: Verinin kendisi + veriye ulaşan her şey. Ekran (View) ve ekran mantığı (ViewModel) burada YOK.
//
// ALT KLASÖRLER (her birinin kendi 00_Rehber dosyası var)
//  ── Veri kalıpları (JSON'un Swift hâli) ──
//  Auth/            giriş, kayıt, hesap bilgileri, doğrulama kodu, şikâyet/engelle paketleri
//  Listings/        ilan, filtre, sayfa zarfı, sıralama, sayaçlar, emsal fiyat
//  Offers/          teklif (3 bakış açısı), iş aşaması, iptal talebi, puan, profiller
//  Chat/            sohbet mesajı
//  Notifications/   bildirim modeli + PushManager (izin, APNs jetonu)
//  Geography/       il, ilçe
//  Vehicles/        araç, araç türü
//  ── Sunucuya konuşan katman ──
//  Services/        her fonksiyon = bir API ucu (AuthService, ListingService, OfferService…)
//    └ Protocols/   servis sözleşmeleri (ViewModel bunlara bağlı → testte sahtesi takılır)
//  Networking/      APIClient (tek kapı: gönder, jeton ekle, 401'de yenile, hatayı Türkçeye çevir) · AuthSession · APIConfig
//  ── Yardımcılar ──
//  Security/        Keychain (yenileme jetonu) · sabit cihaz kimliği
//  Location/        telefonun konumu ("bana yakın")
//
// YAZIM KURALLARI (bütün Models)
//  …Request          Encodable: sunucuya GİDEN paket
//  …Response / düz ad (Listing, CarrierOffer)   Decodable: sunucudan GELEN cevap
//  Alan adları sunucuyla birebir (camelCase). Enum'lar sunucudaki yazıyla (rawValue "Truck", "Pending").
//  Sunucuya SONRADAN eklenen alan → "var x: T? = nil" (eski cevapta yoksa çözümleme düşmesin).
//    DERS: "var x: [T] = []" alan yoksa çözümlemeyi DÜŞÜRÜR → Optional yaz.
//  Kimlik (id) String (GUID); il/ilçe Int (plaka kodu).
//
// ZİNCİR: View → ViewModel → Services/…Service → Networking/APIClient → HTTP+JSON → backend Controllers → veritabanı
