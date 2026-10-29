//
//  CreateListingView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 29.10.2026.
//

import SwiftUI

// BU EKRAN: Yük Veren'in ilan ver formu. Akış: alanları doldur → kontrol et → (sonra) pakete koy → API'ye gönder
// BAĞLANTI: HomeView.swift'teki "İlan Ver" NavigationLink'i bu ekranı açar (yalnız Shipper rolünde) | il listesi Network/CityService.swift'ten gelir
struct CreateListingView: View {

    // @State [SWIFT]: ekranın hafızası; değer değişince ekran kendini yeniler
    @State private var title = "" // başlık, örn. "20 palet tarım ilacı"
    @State private var details = "" // açıklama, isteğe bağlı
    @State private var weightKg = "" // TextField yazı tuttuğu için String; göndermeden önce sayıya çevireceğiz
    @State private var vehicleType = "" // seçili araç türü; API'ye bu metin gider | "" = henüz seçilmedi
    @State private var pickupDate = Date() // Date() [SWIFT]: şu anki tarih | DatePicker'ın seçtiği tarih buraya yazılır
    @State private var budget = "" // beklenen fiyat, isteğe bağlı
    @State private var errorMessage: String? // nil: hata yok, dolu: ekranda kırmızı yazılır
    
    // cities: API'den gelen il listesi | [ ] = liste, başta boş | City kalıbı: Network/CityModels.swift
    // Doldurulduğu yer: aşağıdaki .task (CityService().cities() → Network/CityService.swift) | Gösterildiği yer: aşağıdaki "Kalkış İli" ve "Varış İli" Picker'ları
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
    private let vehicleTypes = [
        ("Truck","Tır"),
        ("Lorry","Kamyon"),
        ("Pickup","Kamyonet"),
        ("Refrigerated","Frigorifik"),
        ("Other","Diğer")
    ]
    
    var body: some View {
        
        ScrollView{ // uzun formda kaydırma
            
            VStack(spacing: 24){
                
                Text("İlan Ver").font(.largeTitle).bold()
                
                TextField("Başlık", text: $title).textFieldStyle(.roundedBorder) // $: iki yönlü bağ, yazılan yazı doğrudan değişkene gider
                
                TextField("Açıklama (isteğe bağlı)",text: $details).textFieldStyle(.roundedBorder)
                
                TextField("Ağırlık (kg)", text: $weightKg).keyboardType(.numberPad).textFieldStyle(.roundedBorder) // .numberPad: sadece rakam klavyesi
                
                Picker("Kalkış İli", selection: $fromCityId) {
                    
                    Text("Kalkış İlini Seçiniz !").tag(0) // tag(0): hiçbir şey seçilmemişken bu yazı görünür
                    
                    ForEach(cities) { city in   // cities: .task'ta CityService'ten dolan liste | City Identifiable olduğu için id: yazmak gerekmiyor
                        
                        Text(city.name).tag(city.id) // city.name: ekranda görünen ad | city.id = tag: değişkene yazılacak numara
                        
                    }
                    
                    
                }.pickerStyle(.menu)
                    .onChange(of: fromCityId) { _, newId in
                        fromDistrictId = 0
                        fromDistricts = []
                        if newId == 0 {return}
                        Task { // Task: burada await kullanabilmek için

                                    // BAĞLANTI: CityService().districts(cityId:) → Network/CityService.swift'teki func districts → API'ye GET → [District] döner
                                    fromDistricts = (try? await CityService().districts(cityId: newId)) ?? []
                        }
                    }
                
                if fromCityId != 0 { // il seçilmeden ilçe listesi görünmesin
                    Picker("Kalkış İlçesi", selection: $fromDistrictId) {
                        Text("Kalkış İlçesini Seçiniz").tag(0)
                        ForEach(fromDistricts) { district in
                            Text(district.name).tag(district.id)
                        }
                    }.pickerStyle(.menu)
                }
                
                // VARIŞ: kalkıştaki bloğun aynısı, sadece to... değişkenleri | önce il, sonra o ilin ilçeleri
                Picker("Varış İli", selection: $toCityId) { // seçilen il numarası $toCityId'ye yazılır
                    Text("Varış İlini Seçiniz !").tag(0)
                    ForEach(cities) { city in // aynı cities listesi (kalkış ve varış aynı 81 ili kullanır)
                        Text(city.name).tag(city.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: toCityId) { _, newId in // varış ili değişince çalışır
                    toDistrictId = 0 // eski ilçe seçimi geçersiz
                    toDistricts = []
                    if newId == 0 { return }
                    Task {
                        // BAĞLANTI: CityService().districts(cityId:) → Network/CityService.swift → API'ye GET → [District] → toDistricts'e yazılır
                        toDistricts = (try? await CityService().districts(cityId: newId)) ?? []
                    }
                }

                if toCityId != 0 { // il seçilmeden ilçe listesi görünmesin
                    Picker("Varış İlçesi", selection: $toDistrictId) {
                        Text("Varış İlçesini Seçiniz").tag(0)
                        ForEach(toDistricts) { district in
                            Text(district.name).tag(district.id)
                        }
                    }.pickerStyle(.menu)
                }

                
                // Picker: açılır liste | selection: seçilen değer $vehicleType'a yazılır
                
                Picker("İstenen Araç", selection: $vehicleType) {
                    
                    Text("Araç Türünü Seçiniz !").tag("") // tag(""): hiçbir şey seçilmemişken bu yazı görünür
                    
                    ForEach(vehicleTypes,id: \.0){ type in // id: \.0 = benzersiz anahtar olarak çiftin 1. elemanı
                        
                        Text(type.1).tag(type.0) // type.1: ekranda görünen ad | type.0 = tag: değişkene yazılacak API değeri
                    }
                    
                }.pickerStyle(.menu)
                
                // DatePicker [SWIFT]: tarih seçici | selection: seçilen tarih $pickupDate'e yazılır
                // in: Date()...: bugünden öncesi seçilemez | displayedComponents: .date → sadece gün, saat yok
                
                DatePicker("Yükleme Tarihi",selection: $pickupDate,in: Date()..., displayedComponents: .date)
                
                TextField("Bütçe (isteğe bağlı)",text: $budget).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                
                if let errorMessage {Text(errorMessage).foregroundColor(.red)} // doluysa kırmızı yaz nil ise çizilmez
                
                Button("İlanı Yayınla"){
                    
                    // ---- KONTROLLER: API'ye gitmeden ekranda yakalıyoruz (return: burada dur) ----
                    
                    if title.isEmpty {
                        errorMessage = "Başlığı Giriniz !"
                        return // return: burada dur, aşağıdaki kontrollere geçme (yazmazsak kod devam eder!)
                    }
                    
                    guard let weight = Int(weightKg) else { // Int("500") → 500, Int("abc") → nil
                        
                        errorMessage = "Ağırlık sayı olmalı"
                        return
                    }
                    
                    if vehicleType.isEmpty {
                        errorMessage = "Araç türünü seçiniz"
                        return
                    }
                    if fromCityId == 0 || fromDistrictId == 0 || toCityId == 0 || toDistrictId == 0 { // dördünden biri seçilmediyse
                        errorMessage = "Kalkış ve varış il-ilçesini seçiniz"
                        return
                    }
                    errorMessage = nil
                    print("İLAN HAZIR : \(title) \(weight) kg \(vehicleType), \(pickupDate), kalkış \(fromCityId)/\(fromDistrictId) varış \(toCityId)/\(toDistrictId)") // geçici: API bağlanana kadar konsola yazar | numaralar seçilen il/ilçe id'leri
                    
                    
                }.buttonStyle(.borderedProminent)



            }.padding() // formun kenarlarına boşluk (diğer ekranlardaki gibi)

        }
        .task { // [SWIFT]: ekran açılınca bir kez çalışır | içinde await kullanılabilir | ScrollView'in hemen altında, body'nin İÇİNDE olmalı
            // BAĞLANTI: CityService, Network/CityService.swift'te tanımlı. .cities() oradaki func cities'i çağırır → API'ye GET atar →
            // gelen JSON, Network/CityModels.swift'teki City kalıbına çevrilip [City] olarak döner → "cities" değişkenine yazılır.
            cities = (try? await CityService().cities()) ?? [] // try?: hata olursa nil ver | ?? []: nil ise boş liste
            print("İL SAYISI: \(cities.count)") // geçici: konsolda 81 görmeliyiz
        }

    }


}

#Preview {
    CreateListingView()
}
