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
                    // .onChange: "fromCityId değişince bu bloğu bir kez çalıştır" (ayrıntılı anlatım aşağıdaki Varış bloğunda, mantık birebir aynı)
                    // BAĞLANTI: fromCityId'yi yukarıdaki "Kalkış İli" Picker'ı değiştirir → burası çalışır → sonuç fromDistricts'e yazılır → "Kalkış İlçesi" Picker'ı gösterir
                    .onChange(of: fromCityId) { _, newId in // _ = eski değer (kullanmıyoruz) | newId = seçilen ilin yeni numarası, adı bizim
                        fromDistrictId = 0 // eski ilçe seçimini sıfırla (başka ile ait kalmasın)
                        fromDistricts = [] // eski ilçe listesini boşalt
                        if newId == 0 {return} // "Seçiniz"e dönüldüyse çekme, bloktan çık
                        Task { // Task: burada await kullanabilmek için

                                    // BAĞLANTI: CityService().districts(cityId:) → Network/CityService.swift'teki func districts → API'ye GET → [District] döner
                                    // try? = hata olursa nil ver | await = cevabı bekle | ?? [] = nil ise boş liste | sonuç @State'e yazılınca ilçe Picker'ı kendini yeniler
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
                // ---- .onChange NEDİR? [SWIFT: SwiftUI'nin hazır özelliği] ----
                // "Bir değişkeni izle. Değişince süslü parantezdeki kodu BİR KEZ çalıştır." Düğme gerekmez, değişim yeter.
                // Neden lazım: kullanıcı il seçerken düğmeye basmaz, Picker sadece toCityId'yi değiştirir. İlçeleri çekeceğimiz anı bu yakalar.
                // BAĞLANTI: toCityId'yi yukarıdaki "Varış İli" Picker'ı değiştirir (selection: $toCityId) → değişince burası çalışır
                //           → sonuç toDistricts'e yazılır → aşağıdaki "Varış İlçesi" Picker'ı o listeyi gösterir.
                .onChange(of: toCityId) { _, newId in // of: izlenen değişken (varış ili numarası) | { eski, yeni in ... }: değişince Swift bize iki değer verir
                    // _  = ESKİ değer. Bize lazım değil, alt çizgi "yok say" demek.
                    // newId = YENİ değer. Adını biz koyduk [BİZİM]. Seçilen ilin numarası (örn. 34). `in` = solda isimler, sağda yapılacak iş.

                    toDistrictId = 0 // ilçe seçimini "seçilmedi"ye döndür | neden: eski ilin ilçesi yeni ile ait değil, kalırsa yanlış ilan gider
                    toDistricts = [] // eski ilçe listesini boşalt | [] = boş liste | ekran listeyi hemen temizler, yenisi gelene kadar eski görünmez

                    if newId == 0 { return } // kullanıcı "Seçiniz"e döndüyse (0) çekecek il yok | return = bu bloktan çık, aşağıdaki satırlar çalışmaz

                    Task { // Task [SWIFT]: arka planda iş başlatır | neden: .onChange bekleyemez, internet isteği ise bekletir (await); await yalnız Task içinde yazılır
                        // CityService() = Network/CityService.swift'teki struct'ın bir örneği (() ile üretilir)
                        // .districts(cityId: newId) = onun fonksiyonu; il numarasını alır, API'ye GET /api/v1/cities/34/districts atar, [District] döner
                        // await = cevap gelene kadar bekle (ekran donmaz) | try? = hata olursa (internet yok) çökme, nil ver | ?? [] = nil ise boş liste kullan
                        // sonuç toDistricts'e yazılır. toDistricts @State olduğu için değişince ekran yenilenir, ilçe Picker'ı dolar.
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
