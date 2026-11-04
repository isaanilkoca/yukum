//
//  CreateListingViewModel.swift
//  Yukum
//

import Foundation
import Observation

// ┌─ BAĞLANTI HARİTASI: CreateListingViewModel ──────────────────────────────────────
// │ EKRAN     : Views/CreateListingView (@State private var viewModel) — "İlan Ver" formu
// │ SERVİS    : Services/Protocols/ListingServicing → ListingService.create | CityServicing → CityService
// │ MODEL     : CreateListingRequest (giden), ListingResponse (gelen), City, District
// │ AKIŞ      : Alanlar $viewModel.x ile doldurulur → "İlanı Yayınla" → submit(): doğrula → CreateListingRequest → ListingService.create → true ise View kapanır
// └──────────────────────────────────────────────────────────────────────

// BU SINIF: "İlan Ver" formunun durumu ve mantığı (alanlar, il→ilçe zinciri, doğrulama, paket hazırlama, gönderme)
// BAĞLANTI: Views/CreateListingView.swift kullanır | servisler: Services/ListingService.swift (ListingServicing), Services/CityService.swift (CityServicing) | paket kalıbı: Models/Listings/
@Observable
final class CreateListingViewModel {

    private let listingService: ListingServicing
    private let cityService: CityServicing

    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Başlık", text: $viewModel.title) | submit() boş mu bakar, CreateListingRequest.title'a koyar
    var title = "" // başlık, örn. "20 palet tarım ilacı"
    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Açıklama") | CreateListingRequest.description (boşsa nil)
    var details = "" // açıklama, isteğe bağlı
    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Ağırlık (kg)") — yazı olarak tutulur, submit() Int'e çevirir | CreateListingRequest.weightKg
    var weightKg = "" // TextField yazı tuttuğu için String; göndermeden önce Int'e çevrilir
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("İstenen Araç", selection: $viewModel.vehicleType) | CreateListingRequest.vehicleType
    var vehicleType = "" // seçili araç türü; API'ye bu metin gider | "" = henüz seçilmedi
    // ⮕ ZİNCİR: Views/CreateListingView: DatePicker | submit() formatDate ile "yyyy-MM-dd" yazısına çevirir → CreateListingRequest.pickupDate
    var pickupDate = Date() // Date() [SWIFT]: şu anki tarih | DatePicker'ın seçtiği tarih
    // ⮕ ZİNCİR: Views/CreateListingView: TextField("Bütçe") | boşsa nil, doluysa Int | CreateListingRequest.budget
    var budget = "" // beklenen fiyat, isteğe bağlı
    // ⮕ ZİNCİR: Views/CreateListingView: if let errorMessage → kırmızı yazı | submit()'in doğrulama mesajları ve sunucu hatası
    var errorMessage: String? // nil: hata yok, dolu: ekranda kırmızı yazılır
    // ⮕ ZİNCİR: Views/CreateListingView: "İlanı Yayınla" düğmesi .disabled(viewModel.isLoading) — çift tıklamayı engeller
    var isLoading = false // istek sürerken true → düğmeyi kilitlemekte kullanılır (çift tıklama olmasın)

    // ⮕ ZİNCİR: Views/CreateListingView: Kalkış İli ve Varış İli Picker'ları | DOLDURAN: loadCities() ← CityService.cities() | MODEL: [City]
    var cities: [City] = [] // API'den gelen il listesi | "Kalkış İli" ve "Varış İli" Picker'ları bundan çizilir
    // 0 = henüz seçilmedi (gerçek il/ilçe numarası 0 olmaz) | seçilince City.id / District.id yazılır
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Kalkış İli") seçimi | değişince .onChange → fromCityChanged(to:)
    var fromCityId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Kalkış İlçesi") seçimi | CreateListingRequest.fromDistrictId
    var fromDistrictId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Varış İli") seçimi | değişince .onChange → toCityChanged(to:)
    var toCityId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Picker("Varış İlçesi") seçimi | CreateListingRequest.toDistrictId
    var toDistrictId = 0
    // ⮕ ZİNCİR: Views/CreateListingView: Kalkış İlçesi Picker'ının satırları | DOLDURAN: fromCityChanged ← CityService.districts | MODEL: [District]
    var fromDistricts: [District] = [] // il seçilince çekilen ilçe listeleri
    // ⮕ ZİNCİR: Views/CreateListingView: Varış İlçesi Picker'ının satırları | DOLDURAN: toCityChanged ← CityService.districts | MODEL: [District]
    var toDistricts: [District] = []

    // (API'ye giden değer, ekranda görünen ad) çiftleri | kayıttaki liste ile aynı (Views/CarrierRegisterView.swift)
    // ⮕ ZİNCİR: Views/CreateListingView: araç Picker'ının seçenekleri (API değeri, görünen ad) çiftleri
    static let vehicleTypes = [("Truck", "Tır"), ("Lorry", "Kamyon"), ("Pickup", "Kamyonet"), ("Refrigerated", "Frigorifik"), ("Other", "Diğer")]
    // Sınırlar sunucudaki ile AYNI: aşırı büyük değer sunucuda 400 verirdi, burada daha ekranda yakalanır
    static let maxWeightKg = 1_000_000
    static let maxBudget = 100_000_000

    init(listingService: ListingServicing = ListingService(), cityService: CityServicing = CityService()) {
        self.listingService = listingService
        self.cityService = cityService
    }

    // loadCities: ekran açılınca il listesini çeker | try?: hata olursa nil | ?? []: nil ise boş liste
    // ⮕ ZİNCİR: Views/CreateListingView: .task { await viewModel.loadCities() } | CityService.cities()
    func loadCities() async {
        if cities.isEmpty { cities = (try? await cityService.cities()) ?? [] }
    }

    // fromCityChanged / toCityChanged: il Picker'ı değişince | ilçe seçimini sıfırlar (eski ilin ilçesi yeni ile ait değil, kalırsa yanlış ilan gider) ve yeni ilin ilçelerini çeker
    // ⮕ ZİNCİR: Views/CreateListingView: kalkış il Picker .onChange | CityService.districts(cityId:) → fromDistricts
    func fromCityChanged(to cityId: Int) async {
        fromDistrictId = 0
        fromDistricts = []
        guard cityId != 0 else { return } // "Seçiniz"e dönüldüyse çekecek il yok
        fromDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // ⮕ ZİNCİR: Views/CreateListingView: varış il Picker .onChange | CityService.districts(cityId:) → toDistricts
    func toCityChanged(to cityId: Int) async {
        toDistrictId = 0
        toDistricts = []
        guard cityId != 0 else { return }
        toDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // formatDate: Date → API'nin istediği yazı "2026-11-05" (yıl-ay-gün, saat yok)
    // en_US_POSIX: telefonun diline göre rakamlar/ay adları bozulmasın | static: testte doğrudan çağrılabilsin
    // ⮕ ZİNCİR: submit() içinde pickupDate'i API'nin istediği "2026-11-05" yazısına çevirir (testte doğrudan denenir)
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter() // DateFormatter [SWIFT]: tarih ↔ yazı çevirici
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    // submit: "İlanı Yayınla" | -> Bool: başarılı mı (ekran başarılıysa HomeView'a döner)
    // ⮕ ZİNCİR: Views/CreateListingView: Button("İlanı Yayınla") { Task { if await viewModel.submit() { dismiss() } } } | ListingService.create(CreateListingRequest) → ListingResponse
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

        isLoading = true // düğme kilitlenir
        defer { isLoading = false }
        do {
            _ = try await listingService.create(request) // POST /api/v1/listings
            return true
        } catch {
            if let message = error.userMessage { errorMessage = message } // API'nin Türkçe mesajı kırmızı yazılır
            return false
        }
    }
}
