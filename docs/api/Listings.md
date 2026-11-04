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
