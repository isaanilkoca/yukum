# İlan güncelleme — sözleşme kartı (Aşama E3)

```
Uç:        PUT /api/v1/listings/{id}
Yetki:     Shipper (yalnız ilanın sahibi)
İstek:     tam değiştirme, ilan açmayla aynı alanlar:
           { title, description?, weightKg, vehicleType, fromCityId, fromDistrictId,
             toCityId, toDistrictId, pickupDate (yyyy-MM-dd), budget? }
Başarı:    200 + ListingDto (güncel ilan)
Hatalar:   400 doğrulama (ilan açmayla aynı kurallar, Türkçe mesaj)
           401 jeton yok · 403 rol Shipper değil
           404 ilan yok ya da başkasının (varlığı sızdırılmaz)
           409 ilan "Açık" değil: teklif kabul edilmiş ("Teklif kabul edilmiş ilan güncellenemez.")
               ya da tamamlanmış/kaldırılmış ("Tamamlanmış ya da kaldırılmış ilan güncellenemez.")
iOS:       ListingService.update(id:_:) • UpdateListingRequest • ListingDto/Listing • düzenleme ViewModel'i • düzenleme ekranı
Kabul:     Shipper kendi açık ilanını günceller 200; başkası 404; Carrier 403; atanmış/tamamlanmış/kaldırılmış 409
```

**Kurallar**
- Sıra: 404 (sahip değil) → 409 (açık değil) → 400 (doğrulama). Reddedilen istek ilanı değiştirmez.
- Bekleyen teklifler korunur; Taşımacı Tekliflerim'de güncel ilan bilgisini görür.
- Doğrulama `CreateListingValidator` ile tek kaynaktır (kural kopyalanmadı).
- Teklif kabul edildikten sonra değişiklik yok: anlaşma eski bilgilere göre yapılmıştır.

---

# Açık ilan listesi — sayfalama, filtre, sıralama (Aşama E4)

```
Uç:        GET /api/v1/listings            (yalnız Carrier; Shipper 403, jeton yok 401)
Sorgu:     hepsi isteğe bağlı
           fromCityId, fromDistrictId, toCityId           kalkış il/ilçe, varış ili
           minBudget, maxBudget                           fiyat aralığı (bütçesi boş ilan aralığa girmez)
           vehicleType                                    Truck | Lorry | Pickup | Refrigerated | Other
           pickupFrom, pickupTo                           yükleme tarihi aralığı (yyyy-MM-dd)
           sort                                           Newest | PriceAsc | PriceDesc | Nearest
           lat, lon                                       konum (birlikte; kaydedilmez)
           page (=1), pageSize (=20, en çok 50)
Başarı:    200 { items: [ListingDto], page, pageSize, totalCount }   (totalCount = filtreye uyan TÜM ilan)
Hatalar:   400 geçersiz parametre (page<1, pageSize 1..50 dışı, min>max, negatif fiyat, from>to tarih,
               sort=Nearest konumsuz, lat/lon tek başına, geçersiz sort/vehicleType)
iOS:       Page<T> • ListingService.openListings(filtre…, page) • HomeViewModel (sayfalama, filtre durumu) • filtre sheet
Kabul:     her filtre tek başına ve birlikte doğru; sayfalar birleşince tekrar/kayıp yok; totalCount tüm sayfalarda aynı
```

**Kurallar**
- Varsayılan sıra: konum varsa en yakın, yoksa en yeni. Fiyat sıralamasında bütçesi boş ilanlar hep sonda.
- Kararlı sıralama: son anahtar Id (fiyat ya da tarih eşit olsa da sayfalar tutarlı).
- Teklif verdiğin ilan (durumu ne olursa olsun) listede ve toplamda çıkmaz (Tekliflerim'e geçer).
- Filtre, sıralama, sayfalama ve sayım SQL'de (`ListingSearchRepository`). Yalnız `Nearest` sıralamada mesafe bellekte hesaplanır (spatial index: Aşama J1).
- **Kırıcı değişiklik:** cevap artık dizi değil zarf; iOS aynı anda güncellenir.
- İndeksler: `(Status, CreatedAt)`, `(Status, ToCityId, CreatedAt)`.
