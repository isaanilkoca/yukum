# iOS Klasör Rehberi — ne nerede

Her şey 3 başlık altında (MVVM), uygulamanın girişi `App/`:

```
ios/Yukum/Yukum/
├─ Views/        GÖRÜNÜM: yalnız çizim (12 ekran)
├─ ViewModels/   DURUM + KURAL: kontroller, yükleniyor/hata, servisi çağırır
├─ Models/       VERİ TARAFI
│   ├─ Auth/ Listings/ Offers/ Chat/ Geography/ Vehicles/   JSON'un Swift hâli (Request/Response)
│   ├─ Services/    API'ye konuşan yer (her fonksiyon bir API ucu) + Protocols/ (sözleşmeler)
│   ├─ Networking/  APIClient (ağın tek kapısı), AuthSession (jetonlar), hata türleri
│   ├─ Security/    Keychain, cihaz kimliği
│   └─ Location/    telefonun konumu
└─ App/          uygulamanın girişi
```

**Her klasörün ilk dosyası** `00_Rehber_<klasör>.swift`: o klasördeki her sınıfın ne işe yaradığı,
hangi API'ye gittiği ve onu hangi klasördeki hangi sınıfın çağırdığı. Kod içermez, sadece yorumdur.

Akış: `Views → ViewModels → Models/Services → Models/Networking/APIClient → sunucu` (cevap aynı yoldan döner).
Örnek "Teklif ver": `ListingDetailView` → `ListingDetailViewModel.submit()` → `OfferService.create` → `APIClient` → `POST /listings/{id}/offers`.
