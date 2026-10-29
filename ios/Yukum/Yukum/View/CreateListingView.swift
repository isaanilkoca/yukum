//
//  CreateListingView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: Yük Veren'in ilan ver formu. Akış: alanları doldur → kontrol et → (sonra) pakete koy → API'ye gönder
// BAĞLANTI: HomeView.swift'teki "İlan Ver" NavigationLink'i bu ekranı açar (yalnız Shipper rolünde) | il/ilçe listesi Network/CityService.swift'ten gelir
//           Paket kalıbı: Network/ListingRequest.swift → CreateListingRequest | gönderecek servis: Network/ListingService.swift
struct CreateListingView: View { // CreateListingView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // @State [SWIFT]: ekranın hafızası; değer değişince ekran kendini yeniler | private: yalnız bu ekran kullanır
    @State private var title = "" // başlık, örn. "20 palet tarım ilacı"
    @State private var details = "" // açıklama, isteğe bağlı
    @State private var weightKg = "" // TextField yazı tuttuğu için String; göndermeden önce Int'e çevrilir
    @State private var vehicleType = "" // seçili araç türü; API'ye bu metin gider | "" = henüz seçilmedi
    @State private var pickupDate = Date() // Date() [SWIFT]: şu anki tarih | DatePicker'ın seçtiği tarih buraya yazılır
    @State private var budget = "" // beklenen fiyat, isteğe bağlı
    @State private var errorMessage: String? // nil: hata yok, dolu: ekranda kırmızı yazılır

    // cities: API'den gelen il listesi | [City] = City'lerden oluşan liste, başta boş | City kalıbı: Network/CityModels.swift
    // Doldurulduğu yer: aşağıdaki .task (CityService().cities() → Network/CityService.swift) | Gösterildiği yer: "Kalkış İli" ve "Varış İli" Picker'ları
    @State private var cities: [City] = []

    // 0 = henüz seçilmedi (gerçek il/ilçe numarası 0 olmaz) | seçilince City.id / District.id buraya yazılır (kalıplar: Network/CityModels.swift)
    @State private var fromCityId = 0 // kalkış ili
    @State private var fromDistrictId = 0 // kalkış ilçesi
    @State private var toCityId = 0 // varış ili
    @State private var toDistrictId = 0 // varış ilçesi

    // il seçilince API'den çekilen ilçe listeleri | doldurulduğu yer: aşağıdaki .onChange (CityService().districts → Network/CityService.swift)
    @State private var fromDistricts: [District] = []
    @State private var toDistricts: [District] = []

    // (API'ye giden değer, ekranda görünen ad) çiftleri | kayıttaki liste ile aynı (View/CarrierRegisterView.swift)
    private let vehicleTypes = [ // let [SWIFT]: değişmeyen değer | [ ] = liste, her eleman bir çift ( , )
        ("Truck", "Tır"),
        ("Lorry", "Kamyon"),
        ("Pickup", "Kamyonet"),
        ("Refrigerated", "Frigorifik"),
        ("Other", "Diğer")
    ]

    var body: some View { // ekranın içeriği

        ScrollView { // ScrollView [SWIFT]: uzun formda kaydırma

            VStack(spacing: 24) { // VStack [SWIFT]: elemanları alt alta dizer | spacing: elemanlar arası boşluk

                Text("İlan Ver").font(.largeTitle).bold()

                TextField("Başlık", text: $title).textFieldStyle(.roundedBorder) // $ = iki yönlü bağ: yazılan yazı doğrudan değişkene gider

                TextField("Açıklama (isteğe bağlı)", text: $details).textFieldStyle(.roundedBorder)

                TextField("Ağırlık (kg)", text: $weightKg).keyboardType(.numberPad).textFieldStyle(.roundedBorder) // .numberPad: sadece rakam klavyesi

                // ---- KALKIŞ: önce il, il seçilince o ilin ilçeleri ----
                Picker("Kalkış İli", selection: $fromCityId) { // Picker [SWIFT]: açılır liste | selection: seçilen değer $fromCityId'ye yazılır

                    Text("Kalkış İlini Seçiniz !").tag(0) // tag(0): hiçbir şey seçilmemişken bu yazı görünür, değeri 0

                    ForEach(cities) { city in // ForEach [SWIFT]: listedeki her eleman için bir satır çizer | cities: .task'ta dolan liste | City Identifiable olduğu için id: yazmak gerekmiyor
                        Text(city.name).tag(city.id) // city.name: ekranda görünen ad | city.id = tag: seçilince değişkene yazılacak numara
                    }

                }.pickerStyle(.menu) // açılır menü görünümü
                    // .onChange [SWIFT]: bir değişkeni izler, değişince süslü parantezdeki kodu BİR KEZ çalıştırır. Kullanıcı il seçerken düğmeye basmaz, değişkenin değişmesi tetikler.
                    // BAĞLANTI: fromCityId'yi yukarıdaki "Kalkış İli" Picker'ı değiştirir → burası çalışır → sonuç fromDistricts'e yazılır → "Kalkış İlçesi" Picker'ı gösterir
                    .onChange(of: fromCityId) { _, newId in // of: izlenen değişken | _ = ESKİ değer, kullanmıyoruz (yok say) | newId = YENİ değer, adı bizim | in = solda isimler, sağda yapılacak iş
                        fromDistrictId = 0 // ilçe seçimini sıfırla | neden: eski ilin ilçesi yeni ile ait değil, kalırsa yanlış ilan gider
                        fromDistricts = [] // eski ilçe listesini boşalt | [] = boş liste
                        if newId == 0 { return } // "Seçiniz"e dönüldüyse çekecek il yok | return = bloktan çık, aşağısı çalışmaz
                        Task { // Task [SWIFT]: arka planda iş başlatır | neden: .onChange bekleyemez, internet isteği bekletir (await); await yalnız Task içinde yazılır
                            // BAĞLANTI: CityService().districts(cityId:) → Network/CityService.swift'teki func districts → API'ye GET /api/v1/cities/34/districts → [District] döner
                            // try? = hata olursa (internet yok) çökme, nil ver | await = cevabı bekle | ?? [] = nil ise boş liste kullan
                            fromDistricts = (try? await CityService().districts(cityId: newId)) ?? [] // @State değişince ekran yenilenir, ilçe Picker'ı dolar
                        }
                    }

                if fromCityId != 0 { // != "eşit değil" | il seçilmeden ilçe Picker'ı çizilmez; il seçilince @State değişir, ekran yenilenir, Picker görünür
                    Picker("Kalkış İlçesi", selection: $fromDistrictId) { // seçilen ilçe numarası $fromDistrictId'ye yazılır
                        Text("Kalkış İlçesini Seçiniz").tag(0)
                        ForEach(fromDistricts) { district in // .onChange'in doldurduğu liste | District kalıbı: Network/CityModels.swift
                            Text(district.name).tag(district.id)
                        }
                    }.pickerStyle(.menu)
                }

                // ---- VARIŞ: kalkıştaki bloğun aynısı, sadece to... değişkenleri ----
                Picker("Varış İli", selection: $toCityId) { // seçilen il numarası $toCityId'ye yazılır
                    Text("Varış İlini Seçiniz !").tag(0)
                    ForEach(cities) { city in // aynı cities listesi (kalkış ve varış aynı 81 ili kullanır)
                        Text(city.name).tag(city.id)
                    }
                }
                .pickerStyle(.menu)
                // .onChange: toCityId değişince bir kez çalışır (ayrıntılı açıklama yukarıdaki kalkış bloğunda, mantık birebir aynı)
                // BAĞLANTI: toCityId'yi "Varış İli" Picker'ı değiştirir → burası çalışır → sonuç toDistricts'e yazılır → "Varış İlçesi" Picker'ı gösterir
                .onChange(of: toCityId) { _, newId in // _ = eski değer (kullanmıyoruz) | newId = seçilen ilin yeni numarası
                    toDistrictId = 0 // eski ilçe seçimi geçersiz
                    toDistricts = [] // eski ilçe listesini boşalt
                    if newId == 0 { return } // "Seçiniz"e dönüldüyse çekme
                    Task { // await için
                        // BAĞLANTI: CityService().districts(cityId:) → Network/CityService.swift → API'ye GET → [District] → toDistricts'e yazılır
                        toDistricts = (try? await CityService().districts(cityId: newId)) ?? []
                    }
                }

                if toCityId != 0 { // il seçilmeden ilçe Picker'ı çizilmez
                    Picker("Varış İlçesi", selection: $toDistrictId) {
                        Text("Varış İlçesini Seçiniz").tag(0)
                        ForEach(toDistricts) { district in
                            Text(district.name).tag(district.id)
                        }
                    }.pickerStyle(.menu)
                }

                // ---- ARAÇ TÜRÜ ----
                Picker("İstenen Araç", selection: $vehicleType) { // seçilen değer $vehicleType'a yazılır

                    Text("Araç Türünü Seçiniz !").tag("") // tag(""): hiçbir şey seçilmemişken bu yazı görünür

                    ForEach(vehicleTypes, id: \.0) { type in // id: \.0 = benzersiz anahtar olarak çiftin 1. elemanı (Truck, Lorry...) | type: o anki çift (adı bizim)
                        Text(type.1).tag(type.0) // type.1: ekranda görünen Türkçe ad | type.0 = tag: değişkene yazılacak API değeri
                    }

                }.pickerStyle(.menu)

                // DatePicker [SWIFT]: tarih seçici | selection: seçilen tarih $pickupDate'e yazılır
                // in: Date()... = bugünden öncesi seçilemez | displayedComponents: .date → sadece gün, saat yok
                DatePicker("Yükleme Tarihi", selection: $pickupDate, in: Date()..., displayedComponents: .date)

                TextField("Bütçe (isteğe bağlı)", text: $budget).keyboardType(.numberPad).textFieldStyle(.roundedBorder)

                if let errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: doluysa kırmızı yaz, nil ise çizilmez

                Button("İlanı Yayınla") { // tıklanınca süslü parantezdeki kod çalışır

                    // ---- KONTROLLER: API'ye gitmeden ekranda yakalıyoruz (return: burada dur) ----

                    if title.isEmpty { // isEmpty: yazı boş mu
                        errorMessage = "Başlığı Giriniz !"
                        return // return: burada dur, aşağıdaki kontrollere geçme (yazmazsak kod devam eder!)
                    }

                    guard let weight = Int(weightKg) else { // Int("500") → 500, Int("abc") → nil | guard let: nil değilse sonucu weight'e koy ve devam et, nil ise else'e gir
                        errorMessage = "Ağırlık sayı olmalı"
                        return
                    }

                    if vehicleType.isEmpty { // Picker'da hâlâ "Araç Türünü Seçiniz" duruyor
                        errorMessage = "Araç türünü seçiniz"
                        return
                    }

                    if fromCityId == 0 || fromDistrictId == 0 || toCityId == 0 || toDistrictId == 0 { // ||: veya | dördünden biri seçilmediyse
                        errorMessage = "Kalkış ve varış il-ilçesini seçiniz"
                        return
                    }

                    errorMessage = nil // her şey tamam → eski hatayı temizle
                    print("İLAN HAZIR : \(title) \(weight) kg \(vehicleType), \(pickupDate), kalkış \(fromCityId)/\(fromDistrictId) varış \(toCityId)/\(toDistrictId)") // geçici: API bağlanana kadar konsola yazar | \( ) = yazının içine değişken koyar

                }.buttonStyle(.borderedProminent) // dolgulu düğme görünümü

            }.padding() // formun kenarlarına boşluk

        }
        .task { // .task [SWIFT]: ekran açılınca bir kez çalışır | içinde await kullanılabilir | ScrollView'in hemen altında, body'nin İÇİNDE olmalı
            // BAĞLANTI: CityService, Network/CityService.swift'te tanımlı. .cities() oradaki func cities'i çağırır → API'ye GET /api/v1/cities atar →
            // gelen JSON, Network/CityModels.swift'teki City kalıbına çevrilip [City] olarak döner → "cities" değişkenine yazılır.
            cities = (try? await CityService().cities()) ?? [] // try?: hata olursa nil ver | ?? []: nil ise boş liste
            print("İL SAYISI: \(cities.count)") // geçici: konsolda 81 görmeliyiz
        }
    }
}

#Preview { // Xcode önizleme
    CreateListingView()
}
