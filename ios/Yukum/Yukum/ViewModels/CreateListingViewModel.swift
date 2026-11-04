//
//  CreateListingViewModel.swift
//  Yukum
//

import Foundation
import Observation

// BU SINIF: "İlan Ver" formunun durumu ve mantığı (alanlar, il→ilçe zinciri, doğrulama, paket hazırlama, gönderme)
// BAĞLANTI: Views/CreateListingView.swift kullanır | servisler: Services/ListingService.swift (ListingServicing), Services/CityService.swift (CityServicing) | paket kalıbı: Models/Listings/
@Observable
final class CreateListingViewModel {

    private let listingService: ListingServicing
    private let cityService: CityServicing

    var title = "" // başlık, örn. "20 palet tarım ilacı"
    var details = "" // açıklama, isteğe bağlı
    var weightKg = "" // TextField yazı tuttuğu için String; göndermeden önce Int'e çevrilir
    var vehicleType = "" // seçili araç türü; API'ye bu metin gider | "" = henüz seçilmedi
    var pickupDate = Date() // Date() [SWIFT]: şu anki tarih | DatePicker'ın seçtiği tarih
    var budget = "" // beklenen fiyat, isteğe bağlı
    var errorMessage: String? // nil: hata yok, dolu: ekranda kırmızı yazılır
    var isLoading = false // istek sürerken true → düğmeyi kilitlemekte kullanılır (çift tıklama olmasın)

    var cities: [City] = [] // API'den gelen il listesi | "Kalkış İli" ve "Varış İli" Picker'ları bundan çizilir
    // 0 = henüz seçilmedi (gerçek il/ilçe numarası 0 olmaz) | seçilince City.id / District.id yazılır
    var fromCityId = 0
    var fromDistrictId = 0
    var toCityId = 0
    var toDistrictId = 0
    var fromDistricts: [District] = [] // il seçilince çekilen ilçe listeleri
    var toDistricts: [District] = []

    // (API'ye giden değer, ekranda görünen ad) çiftleri | kayıttaki liste ile aynı (Views/CarrierRegisterView.swift)
    static let vehicleTypes = [("Truck", "Tır"), ("Lorry", "Kamyon"), ("Pickup", "Kamyonet"), ("Refrigerated", "Frigorifik"), ("Other", "Diğer")]
    // Sınırlar sunucudaki ile AYNI: aşırı büyük değer sunucuda 400 verirdi, burada daha ekranda yakalanır
    static let maxWeightKg = 1_000_000
    static let maxBudget = 100_000_000

    init(listingService: ListingServicing = ListingService(), cityService: CityServicing = CityService()) {
        self.listingService = listingService
        self.cityService = cityService
    }

    // loadCities: ekran açılınca il listesini çeker | try?: hata olursa nil | ?? []: nil ise boş liste
    func loadCities() async {
        if cities.isEmpty { cities = (try? await cityService.cities()) ?? [] }
    }

    // fromCityChanged / toCityChanged: il Picker'ı değişince | ilçe seçimini sıfırlar (eski ilin ilçesi yeni ile ait değil, kalırsa yanlış ilan gider) ve yeni ilin ilçelerini çeker
    func fromCityChanged(to cityId: Int) async {
        fromDistrictId = 0
        fromDistricts = []
        guard cityId != 0 else { return } // "Seçiniz"e dönüldüyse çekecek il yok
        fromDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    func toCityChanged(to cityId: Int) async {
        toDistrictId = 0
        toDistricts = []
        guard cityId != 0 else { return }
        toDistricts = (try? await cityService.districts(cityId: cityId)) ?? []
    }

    // formatDate: Date → API'nin istediği yazı "2026-11-05" (yıl-ay-gün, saat yok)
    // en_US_POSIX: telefonun diline göre rakamlar/ay adları bozulmasın | static: testte doğrudan çağrılabilsin
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter() // DateFormatter [SWIFT]: tarih ↔ yazı çevirici
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    // submit: "İlanı Yayınla" | -> Bool: başarılı mı (ekran başarılıysa HomeView'a döner)
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
