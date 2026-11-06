//
//  CreateListingViewModel.swift
//  Yukum
//

import Foundation
import Observation // Observation [SWIFT]: @Observable özelliğini veren kütüphane

// ┌─ BAĞLANTI HARİTASI: CreateListingViewModel ──────────────────────────────────────
// │ EKRAN     : Views/CreateListingView (@State private var viewModel) — "İlan Ver" formu
// │ SERVİS    : Models/Services/Protocols/ListingServicing → ListingService.create | CityServicing → CityService
// │ MODEL     : CreateListingRequest (giden), ListingResponse (gelen), City, District
// │ AKIŞ      : Alanlar $viewModel.x ile doldurulur → "İlanı Yayınla" → submit(): doğrula → CreateListingRequest → ListingService.create → true ise View kapanır
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: "İlan Ver" formunun durumu ve mantığı (alanlar, il→ilçe zinciri, doğrulama, paket hazırlama, gönderme)
// BAĞLANTI: Views/CreateListingView.swift kullanır | servisler: Models/Services/ListingService.swift (ListingServicing), Models/Services/CityService.swift (CityServicing) | paket kalıbı: Models/Listings/
// ⮕ KULLANIM [CreateListingViewModel]: kullanır: CreateListingView › viewModel, CreateListingViewModelTests (test)
@Observable // @Observable [SWIFT]: sınıfı gözlemlenebilir yapar: değişkenleri değişince onları okuyan ekranlar kendiliğinden yenilenir
final class CreateListingViewModel {

    // ⮕ KULLANIM [listingService]: okur: CreateListingViewModel › submit()
    private let listingService: ListingServicing
    // ⮕ KULLANIM [cityService]: okur: CreateListingViewModel › loadCities(), CreateListingViewModel › fromCityChanged(), CreateListingViewModel › toCityChanged()
    private let cityService: CityServicing

    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Başlık", text: $viewModel.title) | submit() boş mu bakar, CreateListingRequest.title'a koyar
    // ⮕ KULLANIM [title]: okur: CreateListingViewModel › submit(), CreateListingView › body, CreateListingViewModelTests (test) | bağlar(okur+yazar): CreateListingView › body | YAZAR: CreateListingViewModelTests (test)
    var title = "" // başlık, örn. "20 palet tarım ilacı"
    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Açıklama") | CreateListingRequest.description (boşsa nil)
    // ⮕ KULLANIM [details]: okur: CreateListingViewModel › submit() | bağlar(okur+yazar): CreateListingView › body
    var details = "" // açıklama, isteğe bağlı
    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Ağırlık (kg)") — yazı olarak tutulur, submit() Int'e çevirir | CreateListingRequest.weightKg
    // ⮕ KULLANIM [weightKg]: okur: CreateListingViewModel › submit(), CreateListingViewModelTests (test) | bağlar(okur+yazar): CreateListingView › body | YAZAR: CreateListingViewModelTests (test)
    var weightKg = "" // TextField yazı tuttuğu için String; göndermeden önce Int'e çevrilir
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("İstenen Araç", selection: $viewModel.vehicleType) | CreateListingRequest.vehicleType
    // ⮕ KULLANIM [vehicleType]: okur: CreateListingViewModel › submit() | bağlar(okur+yazar): CreateListingView › body | YAZAR: CreateListingViewModelTests (test)
    var vehicleType = "" // seçili araç türü; API'ye bu metin gider | "" = henüz seçilmedi
    // ⮕ ZİNCİR: Views/CreateListingView: DatePicker | submit() formatDate ile "yyyy-MM-dd" yazısına çevirir → CreateListingRequest.pickupDate
    // ⮕ KULLANIM [pickupDate]: okur: CreateListingViewModel › submit(), CreateListingViewModelTests (test) | bağlar(okur+yazar): CreateListingView › body | YAZAR: CreateListingViewModelTests (test)
    var pickupDate = Date() // Date() [SWIFT]: şu anki tarih | DatePicker'ın seçtiği tarih
    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Bütçe") | boşsa nil, doluysa Int | CreateListingRequest.budget
    // ⮕ KULLANIM [budget]: okur: CreateListingViewModel › submit(), CreateListingViewModelTests (test) | bağlar(okur+yazar): CreateListingView › body | YAZAR: CreateListingViewModelTests (test)
    var budget = "" // beklenen fiyat, isteğe bağlı
    // ⮕ ZİNCİR: Views/CreateListingView: if let errorMessage → kırmızı yazı | submit()'in doğrulama mesajları ve sunucu hatası
    // ⮕ KULLANIM [errorMessage]: YAZAR: CreateListingViewModel › submit() | okur: CreateListingViewModelTests (test)
    var errorMessage: String? // nil: hata yok, dolu: ekranda kırmızı yazılır
    // ⮕ ZİNCİR: Views/CreateListingView: "İlanı Yayınla" düğmesi .disabled(viewModel.isLoading) — çift tıklamayı engeller
    // ⮕ KULLANIM [isLoading]: YAZAR: CreateListingViewModel › submit() | okur: CreateListingView › body, CreateListingViewModelTests (test)
    var isLoading = false // istek sürerken true → düğmeyi kilitlemekte kullanılır (çift tıklama olmasın)
    
    
    // Düzenleme modu: nil = yeni ilan, dolu = o ilan düzenleniyor | DOLDURAN: init(editing:) ← ListingOffersView (Düzenle düğmesi) Listing'i verir
     // let [SWIFT]: bir kez atanır, sonra değişmez | String?: ilan numarası, yoksa nil | KULLANAN: submit() hangi servisi çağıracağına buna bakar
     private let editingId: String?
     // Türetilmiş değerler: View yazıları bunlardan okur, "düzenleme mi" kararı tek yerde kalır | KULLANAN: Views/CreateListingView (adım 5'te bağlayacağız)
     var isEditing: Bool { editingId != nil }
    
    
    // Tam il/ilçe listeleri çekildi mi | düzenlemede başlangıç listesi tek elemanlı, tam liste gelince true olur
    // private [SWIFT]: yalnız bu sınıf görür | KULLANAN: loadCities()
    private var optionsLoaded = false

     var screenTitle: String { isEditing ? "İlanı Düzenle" : "İlan Ver" } // a ? b : c [SWIFT]: a doğruysa b, değilse c
     var submitTitle: String { isEditing ? "İlanı Güncelle" : "İlanı Yayınla" }

    // ⮕ ZİNCİR: Views/CreateListingView: Kalkış İli ve Varış İli Picker'ları | DOLDURAN: loadCities() ← CityService.cities() | MODEL: [City]
    // ⮕ KULLANIM [cities]: YAZAR: CreateListingViewModel › loadCities() | okur: CreateListingView › body
    var cities: [City] = [] // API'den gelen il listesi | "Kalkış İli" ve "Varış İli" Picker'ları bundan çizilir
    // 0 = henüz seçilmedi (gerçek il/ilçe numarası 0 olmaz) | seçilince City.id / District.id yazılır
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Kalkış İli") seçimi | değişince .onChange → fromCityChanged(to:)
    // ⮕ KULLANIM [fromCityId]: okur: CreateListingViewModel › submit(), CreateListingView › body, CreateListingViewModelTests (test) | bağlar(okur+yazar): CreateListingView › body | YAZAR: CreateListingViewModelTests (test)
    var fromCityId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Kalkış İlçesi") seçimi | CreateListingRequest.fromDistrictId
    // ⮕ KULLANIM [fromDistrictId]: YAZAR: CreateListingViewModel › fromCityChanged(), CreateListingViewModelTests (test) | okur: CreateListingViewModel › submit(), CreateListingViewModelTests (test) | bağlar(okur+yazar): CreateListingView › body
    var fromDistrictId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Varış İli") seçimi | değişince .onChange → toCityChanged(to:)
    // ⮕ KULLANIM [toCityId]: okur: CreateListingViewModel › submit(), CreateListingView › body | bağlar(okur+yazar): CreateListingView › body | YAZAR: CreateListingViewModelTests (test)
    var toCityId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Varış İlçesi") seçimi | CreateListingRequest.toDistrictId
    // ⮕ KULLANIM [toDistrictId]: YAZAR: CreateListingViewModel › toCityChanged(), CreateListingViewModelTests (test) | okur: CreateListingViewModel › submit(), CreateListingViewModelTests (test) | bağlar(okur+yazar): CreateListingView › body
    var toDistrictId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Kalkış İlçesi Picker'ının satırları | DOLDURAN: fromCityChanged ← CityService.districts | MODEL: [District]
    // ⮕ KULLANIM [fromDistricts]: YAZAR: CreateListingViewModel › fromCityChanged() | okur: CreateListingView › body, CreateListingViewModelTests (test)
    var fromDistricts: [District] = [] // il seçilince çekilen ilçe listeleri
    // ⮕ ZİNCİR: Views/CreateListingView: Varış İlçesi Picker'ının satırları | DOLDURAN: toCityChanged ← CityService.districts | MODEL: [District]
    // ⮕ KULLANIM [toDistricts]: YAZAR: CreateListingViewModel › toCityChanged() | okur: CreateListingView › body, CreateListingViewModelTests (test)
    var toDistricts: [District] = []

    // Sınırlar sunucudaki ile AYNI: aşırı büyük değer sunucuda 400 verirdi, burada daha ekranda yakalanır
    // ⮕ KULLANIM [maxWeightKg]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    static let maxWeightKg = 1_000_000 // static [SWIFT]: türün kendisine ait (örnek üretmeden erişilir)
    // ⮕ KULLANIM [maxBudget]: başka dosyada kullanılmıyor (yalnız bu dosyada ya da sözleşme gereği)
    static let maxBudget = 100_000_000

    // editing: düzenlenecek ilan | Listing: Models/Listings/Listing.swift (adım 1'de eklediğimiz alanlar burada kullanılır) | = nil: verilmezse yeni ilan, eski çağrılar bozulmaz
        // Alanlar ekran açılmadan DOLDURULUR; sonra kullanıcı değiştirir, submit() olduğu gibi gönderir
        init(editing listing: Listing? = nil, listingService: ListingServicing = ListingService(), cityService: CityServicing = CityService()) {
            self.listingService = listingService
            self.cityService = cityService
            editingId = listing?.id // listing?.id [SWIFT]: listing nil ise nil, doluysa id'yi verir (optional chaining)
            guard let listing else { return } // [SWIFT]: yeni ilan ise doldurulacak bir şey yok | guard let listing: aynı adla paketi açar
            title = listing.title
            details = listing.description ?? "" // ??: nil ise "" (TextField String ister, nil tutamaz)
            weightKg = String(listing.weightKg) // TextField yazı tutar: Int → String
            vehicleType = listing.vehicleType
            budget = listing.budget.map { String(Int($0)) } ?? "" // Optional.map [SWIFT]: doluysa içini çevirir | API Double (5000.0) verir, forma "5000" yazılır
            fromCityId = listing.fromCityId; fromDistrictId = listing.fromDistrictId
            toCityId = listing.toCityId; toDistrictId = listing.toDistrictId
            pickupDate = Self.parseDate(listing.pickupDate) ?? Date() // API yazısı "2026-12-01" → Date | çevrilemezse bugün
            
            // Picker seçimi ilk çizimde geçerli olsun diye listeleri bilinen adlarla tek elemanlı başlatırız (adlar Listing'te hazır)
                   // City / District: Models/Geography | memberwise init [SWIFT]: struct'ın alanlarını sırayla verince otomatik oluşan init
                   cities = [City(id: listing.fromCityId, name: listing.fromCityName)]
                   if listing.toCityId != listing.fromCityId { cities.append(City(id: listing.toCityId, name: listing.toCityName)) } // aynı ilse Picker'da iki kez görünmesin
                   fromDistricts = [District(id: listing.fromDistrictId, name: listing.fromDistrictName)]
                   toDistricts = [District(id: listing.toDistrictId, name: listing.toDistrictName)]

        }

    // loadCities: ekran açılınca il listesini çeker | try?: hata olursa nil | ?? []: nil ise boş liste
    // ⮕ ZİNCİR: Views/CreateListingView: .task { await viewModel.loadCities() } | CityService.cities()
    // ⮕ KULLANIM [loadCities]: çağırır: CreateListingView › body, CreateListingViewModelTests (test)
  
    // loadCities: ekran açılınca il listesini (düzenlemede ilçe listelerini de) çeker
    // ⮕ ZİNCİR: Views/CreateListingView: .task { await viewModel.loadCities() } | CityService.cities() ve (düzenlemede) CityService.districts(cityId:)
    func loadCities() async {
        guard !optionsLoaded else { return } // .task ekran her göründüğünde çalışır; tam liste bir kez yeter | guard [SWIFT]: şart yoksa çık
        // İl listesi gelmediyse (internet yok) bayrak kalkmaz: sonraki .task yeniden dener | try? [SWIFT]: hata olursa nil
        guard let all = try? await cityService.cities(), !all.isEmpty else { return }
        cities = all // yeni ilanda boştu, düzenlemede tek elemanlıydı: tam liste yazılır
        if isEditing {
            // fromCityChanged çağırmıyoruz: o ilçe seçimini SIFIRLAR. View'daki .onChange de yalnız DEĞİŞİNCE tetiklenir, init'teki ilk değer için çalışmaz
            if let list = try? await cityService.districts(cityId: fromCityId) { fromDistricts = list }
            if let list = try? await cityService.districts(cityId: toCityId) { toDistricts = list }
        }
        optionsLoaded = true
    }

    // fromCityChanged / toCityChanged: il Picker'ı değişince | ilçe seçimini sıfırlar (eski ilin ilçesi yeni ile ait değil, kalırsa yanlış ilan gider) ve yeni ilin ilçelerini çeker
    // ⮕ ZİNCİR: Views/CreateListingView: kalkış il Picker .onChange | CityService.districts(cityId:) → fromDistricts
    // ⮕ KULLANIM [fromCityChanged]: çağırır: CreateListingView › body, CreateListingViewModelTests (test)
    func fromCityChanged(to cityId: Int) async {
        fromDistrictId = 0
        fromDistricts = []
        guard cityId != 0 else { return } // "Seçiniz"e dönüldüyse çekecek il yok | guard [SWIFT]: şart sağlanmazsa fonksiyondan erken çık
        fromDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // ⮕ ZİNCİR: Views/CreateListingView: varış il Picker .onChange | CityService.districts(cityId:) → toDistricts
    // ⮕ KULLANIM [toCityChanged]: çağırır: CreateListingView › body, CreateListingViewModelTests (test)
    func toCityChanged(to cityId: Int) async {
        toDistrictId = 0
        toDistricts = []
        guard cityId != 0 else { return }
        toDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // formatDate: Date → API'nin istediği yazı "2026-11-05" (yıl-ay-gün, saat yok)
    // en_US_POSIX: telefonun diline göre rakamlar/ay adları bozulmasın | static: testte doğrudan çağrılabilsin
    // ⮕ ZİNCİR: submit() içinde pickupDate'i API'nin istediği "2026-11-05" yazısına çevirir (testte doğrudan denenir)
    // ⮕ KULLANIM [formatDate]: çağırır: CreateListingViewModel › submit()
  
    // Tek formatter ayarı iki yönde kullanılır: Date → yazı (formatDate) ve yazı → Date (parseDate)
    // static let yerine fonksiyon: DateFormatter thread-safe (Sendable) değil, Swift 6 paylaşımlı sabiti reddeder
    private static func makeDateFormatter() -> DateFormatter { // DateFormatter [SWIFT, Foundation]: tarih ↔ yazı çevirici
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX") // Locale [SWIFT]: telefonun diline göre rakam/ay bozulmasın
        return formatter
    }
    static func formatDate(_ date: Date) -> String { makeDateFormatter().string(from: date) } // ÇAĞIRAN: submit(), testler
    // parseDate: "2026-12-01" → Date | -> Date?: tarih geçersizse nil | ÇAĞIRAN: init(editing:)
    static func parseDate(_ text: String) -> Date? { makeDateFormatter().date(from: text) }
    
    // submit: "İlanı Yayınla" | -> Bool: başarılı mı (ekran başarılıysa HomeView'a döner)
    // ⮕ ZİNCİR: Views/CreateListingView: Button("İlanı Yayınla") { Task { if await viewModel.submit() { dismiss() } } } | ListingService.create(CreateListingRequest) → ListingResponse
    // ⮕ KULLANIM [submit]: çağırır: CreateListingView › body, CreateListingViewModelTests (test)
    func submit() async -> Bool {
        // ---- KONTROLLER: API'ye gitmeden ekranda yakalıyoruz ----
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { errorMessage = "Başlığı Giriniz !"; return false }

        guard let weight = Int(weightKg) else { errorMessage = "Ağırlık sayı olmalı"; return false } // Int("500") → 500, Int("abc") → nil
        guard weight > 0 else { errorMessage = "Ağırlık sıfırdan büyük olmalı"; return false }
        guard weight <= Self.maxWeightKg else { errorMessage = "Ağırlık en fazla 1.000.000 kg olabilir."; return false }

        guard !vehicleType.isEmpty else { errorMessage = "Araç türünü seçiniz"; return false } // Picker'da hâlâ "Araç Türünü Seçiniz" duruyor

        guard fromCityId != 0, fromDistrictId != 0, toCityId != 0, toDistrictId != 0 else { // dördü de seçilmeli
            errorMessage = "Kalkış ve varış il-ilçesini seçiniz"
            return false
        }

        // Bütçe isteğe bağlı: boşsa nil gider (JSON'a yazılmaz), doluysa sayı ve sınır içinde olmalı
        var budgetValue: Int? = nil
        if !budget.isEmpty {
            guard let value = Int(budget) else { errorMessage = "Bütçe sayı olmalı"; return false }
            guard value > 0, value <= Self.maxBudget else { errorMessage = "Bütçe 1 ile 100.000.000 ₺ arasında olmalı."; return false }
            budgetValue = value
        }

        errorMessage = nil // her şey tamam → eski hatayı temizle

        // ---- Paketi doldur | CreateListingRequest, Models/Listings/'te tanımlı (sıra oradaki alan sırasıyla aynı) ----
        let request = CreateListingRequest(title: trimmedTitle,
                                           description: details.isEmpty ? nil : details, // a ? b : c = a doğruysa b, değilse c | boşsa nil: JSON'a hiç yazılmaz
                                           weightKg: weight,
                                           vehicleType: vehicleType,
                                           fromCityId: fromCityId, fromDistrictId: fromDistrictId,
                                           toCityId: toCityId, toDistrictId: toDistrictId,
                                           pickupDate: Self.formatDate(pickupDate),
                                           budget: budgetValue)

        isLoading = true // düğme kilitlenir¨¨
        defer { isLoading = false } // defer [SWIFT]: fonksiyondan çıkarken çalışacak kod
        
                 do {
                  // Aynı form, iki farklı uç: düzenlemede PUT (var olanı değiştir), yeni ilanda POST (oluştur)
                  // listingService: ListingServicing sözleşmesi (Models/Services/Protocols) → gerçekte ListingService.update / create → APIClient
                  if let editingId { // if let [SWIFT]: editingId doluysa içini aynı adla aç
                      _ = try await listingService.update(listingId: editingId, request) // PUT /api/v1/listings/{id}
                  } else {
                      _ = try await listingService.create(request) // POST /api/v1/listings
                  }
                  return true
              }
        catch {
                  if let message = error.userMessage { errorMessage = message } // Core hata çevirici: Models/Networking/Error+UserMessage → "Teklif kabul edilmiş ilan güncellenemez." gibi
                  return false
              } catch {
            if let message = error.userMessage { errorMessage = message } // API'nin Türkçe mesajı kırmızı yazılır
            return false
        }
    }
}
