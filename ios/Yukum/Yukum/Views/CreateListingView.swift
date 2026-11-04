//
//  CreateListingView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi | import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: CreateListingView (İlan Ver formu) ────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ Başlık/Açıklama/Ağırlık/Bütçe/Araç/Tarih  →  viewModel.title, details, weightKg, budget, vehicleType, pickupDate ($ bağlar)  →  CreateListingRequest
// │ Kalkış/Varış il Picker'ı →  viewModel.cities, fromCityId, toCityId  →  CityService.cities()         →  GET /api/v1/cities               →  [City]
// │ Kalkış/Varış ilçe Picker →  viewModel.fromDistricts, toDistricts ← fromCityChanged/toCityChanged  →  CityService.districts()  →  GET /cities/{id}/districts  →  [District]
// │ İlanı Yayınla düğmesi    →  viewModel.submit()                  →  ListingService.create()         →  POST /api/v1/listings            →  CreateListingRequest → ListingResponse
// └──────────────────────────────────────────────────────────────────────

// BU EKRAN: Yük Veren'in ilan ver formu. Akış: alanları doldur → kontrol et → pakete koy → API'ye gönder
// MVVM: bu dosya yalnız GÖRÜNÜM. Alanlar, il→ilçe zinciri, doğrulama, paket hazırlama, gönderme ViewModels/CreateListingViewModel.swift'te.
// BAĞLANTI: HomeView.swift'teki "İlan Ver" NavigationLink'i bu ekranı açar (yalnız Shipper rolünde) | il/ilçe listesi Services/CityService.swift'ten gelir
//           Paket kalıbı: Models/Listings/ → CreateListingRequest | gönderecek servis: Services/ListingService.swift
// ⮕ KULLANIM [CreateListingView]: kullanır: HomeView › body
struct CreateListingView: View { // CreateListingView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // viewModel: formun durumu ve mantığı | @State: ekran yenilense de AYNI nesne yaşar (form alanları kaybolmaz)
    // ⮕ KULLANIM [viewModel]: bağlar(okur+yazar): CreateListingView › body | okur: CreateListingView › body
    @State private var viewModel = CreateListingViewModel() // @State [SWIFT]: ekranın hafızası: değişince ekran yenilenir

    // ⮕ KULLANIM [dismiss]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemin hazır değerini al | dismiss: "bu ekranı kapat" komutu | ilan açılınca HomeView'a dönmek için

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View { // ekranın içeriği

        // @Bindable [SWIFT]: @Observable sınıfın değişkenlerine $ ile İKİ YÖNLÜ bağ kurar (TextField/Picker doğrudan ViewModel'e yazsın diye)
        @Bindable var viewModel = viewModel

        ScrollView { // ScrollView [SWIFT]: uzun formda kaydırma

            VStack(spacing: 24) { // VStack [SWIFT]: elemanları alt alta dizer | spacing: elemanlar arası boşluk

                Text("İlan Ver").font(.largeTitle).bold() // .font [SWIFT]: yazı boyutu/stili | .bold [SWIFT]: yazıyı kalın yapar

                TextField("Başlık", text: $viewModel.title).textFieldStyle(.roundedBorder) // $ = iki yönlü bağ: yazılan yazı doğrudan ViewModel'deki değişkene gider | .textFieldStyle [SWIFT]: yazı kutusu stili

                TextField("Açıklama (isteğe bağlı)", text: $viewModel.details).textFieldStyle(.roundedBorder)

                TextField("Ağırlık (kg)", text: $viewModel.weightKg).keyboardType(.numberPad).textFieldStyle(.roundedBorder) // .numberPad: sadece rakam klavyesi | .keyboardType [SWIFT]: klavye türü

                // ---- KALKIŞ: önce il, il seçilince o ilin ilçeleri ----
                Picker("Kalkış İli", selection: $viewModel.fromCityId) { // Picker [SWIFT]: açılır liste | selection: seçilen değer ViewModel'deki fromCityId'ye yazılır | ⮕ CreateListingViewModel.fromCityId

                    Text("Kalkış İlini Seçiniz !").tag(0) // tag(0): hiçbir şey seçilmemişken bu yazı görünür, değeri 0 | .tag [SWIFT]: Picker seçeneğinin değeri

                    ForEach(viewModel.cities) { city in // ForEach [SWIFT]: listedeki her eleman için bir satır çizer | cities: ViewModel.loadCities'te dolan liste | City Identifiable olduğu için id: yazmak gerekmiyor | ⮕ CreateListingViewModel.cities ← CityService.cities() → [City]
                        Text(city.name).tag(city.id) // city.name: ekranda görünen ad | city.id = tag: seçilince değişkene yazılacak numara
                    }

                }.pickerStyle(.menu) // açılır menü görünümü | .pickerStyle [SWIFT]: seçici görünüm stili
                    // .onChange [SWIFT]: bir değişkeni izler, değişince süslü parantezdeki kodu BİR KEZ çalıştırır. Kullanıcı il seçerken düğmeye basmaz, değişkenin değişmesi tetikler.
                    // il değişince ViewModel ilçe seçimini sıfırlar (eski ilin ilçesi yeni ile ait değil) ve yeni ilin ilçelerini çeker | Task [SWIFT]: .onChange bekleyemez, await yalnız Task içinde yazılır
                    .onChange(of: viewModel.fromCityId) { _, newId in Task { await viewModel.fromCityChanged(to: newId) } } // _ = ESKİ değer, kullanmıyoruz | newId = YENİ değer | ⮕ CreateListingViewModel.fromCityChanged → CityService.districts → fromDistricts

                if viewModel.fromCityId != 0 { // il seçilmeden ilçe Picker'ı çizilmez; il seçilince ekran yenilenir, Picker görünür
                    Picker("Kalkış İlçesi", selection: $viewModel.fromDistrictId) { // seçilen ilçe numarası ViewModel'e yazılır
                        Text("Kalkış İlçesini Seçiniz").tag(0)
                        ForEach(viewModel.fromDistricts) { district in // fromCityChanged'in doldurduğu liste | District kalıbı: Models/Geography/
                            Text(district.name).tag(district.id)
                        }
                    }.pickerStyle(.menu)
                }

                // ---- VARIŞ: kalkıştaki bloğun aynısı, sadece to... değişkenleri ----
                Picker("Varış İli", selection: $viewModel.toCityId) { // seçilen il numarası ViewModel'e yazılır
                    Text("Varış İlini Seçiniz !").tag(0)
                    ForEach(viewModel.cities) { city in // aynı cities listesi (kalkış ve varış aynı 81 ili kullanır)
                        Text(city.name).tag(city.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.toCityId) { _, newId in Task { await viewModel.toCityChanged(to: newId) } } // mantık kalkıştakinin birebir aynısı | ⮕ CreateListingViewModel.toCityChanged → CityService.districts → toDistricts

                if viewModel.toCityId != 0 { // il seçilmeden ilçe Picker'ı çizilmez
                    Picker("Varış İlçesi", selection: $viewModel.toDistrictId) {
                        Text("Varış İlçesini Seçiniz").tag(0)
                        ForEach(viewModel.toDistricts) { district in
                            Text(district.name).tag(district.id)
                        }
                    }.pickerStyle(.menu)
                }

                // ---- ARAÇ TÜRÜ ----
                Picker("İstenen Araç", selection: $viewModel.vehicleType) { // seçilen değer ViewModel'deki vehicleType'a yazılır

                    Text("Araç Türünü Seçiniz !").tag("") // tag(""): hiçbir şey seçilmemişken bu yazı görünür

                    ForEach(VehicleType.allCases) { type in // VehicleType.allCases: bütün araç türleri (Models/Vehicles/VehicleType.swift) | type: o anki tür (adı bizim)
                        Text(type.title).tag(type.rawValue) // type.title: ekranda görünen Türkçe ad | type.rawValue = tag: değişkene yazılacak API değeri ("Truck"...)
                    }

                }.pickerStyle(.menu)

                // DatePicker [SWIFT]: tarih seçici | selection: seçilen tarih ViewModel'deki pickupDate'e yazılır
                // in: Date()... = bugünden öncesi seçilemez | displayedComponents: .date → sadece gün, saat yok
                DatePicker("Yükleme Tarihi", selection: $viewModel.pickupDate, in: Date()..., displayedComponents: .date)

                TextField("Bütçe (isteğe bağlı)", text: $viewModel.budget).keyboardType(.numberPad).textFieldStyle(.roundedBorder)

                if let errorMessage = viewModel.errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: doluysa kırmızı yaz, nil ise çizilmez | .foregroundColor [SWIFT]: yazı rengi

                // Düğme yalnız TETİKLEYİCİ: kontroller (başlık, ağırlık, araç, il-ilçe, bütçe), paket hazırlama (tarih yazıya çevirme dahil) ve gönderme ViewModel.submit()'te
                // başarıda ekran kapanır ve HomeView'a dönülür (HomeView listeyi ekran görününce kendisi yeniler)
                Button("İlanı Yayınla") { // Button [SWIFT]: dokununca kod çalıştıran düğme
                    Task { // Task [SWIFT]: düğmede await kullanmamızı sağlar; ekran donmaz
                        if await viewModel.submit() { dismiss() } // başarılıysa ekranı kapat, HomeView'a dön | ⮕ CreateListingViewModel.submit() → ListingService.create(CreateListingRequest) → POST /api/v1/listings
                    }
                }.buttonStyle(.borderedProminent).disabled(viewModel.isLoading) // dolgulu düğme görünümü | isLoading iken kilitli (çift tıklama olmasın) | .disabled [SWIFT]: koşul doğruysa basılamaz/kilitli | .buttonStyle [SWIFT]: düğme görünüm stili

            }.padding() // formun kenarlarına boşluk | .padding [SWIFT]: etrafında boşluk bırakır

        }
        .task { await viewModel.loadCities() } // .task [SWIFT]: ekran açılınca bir kez çalışır | il listesini API'den çeker | ScrollView'in hemen altında, body'nin İÇİNDE olmalı | ⮕ CreateListingViewModel.loadCities() → CityService.cities()
    }
}

#Preview { // Xcode önizleme | #Preview [SWIFT]: Xcode'da canlı önizleme (uygulamayı etkilemez)
    CreateListingView()
}
