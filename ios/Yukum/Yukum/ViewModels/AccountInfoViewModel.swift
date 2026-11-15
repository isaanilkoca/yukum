//
//  AccountInfoViewModel.swift
//  Yukum
//
//  Hesap Bilgilerim (15 Kasım, yönetici planı 7. adım): bilgileri oku, düzenle, kaydet; profil fotoğrafı yükle/kaldır.
//

import Foundation  // [SWIFT] temel türler
import Observation // [SWIFT] @Observable
import UIKit       // [SWIFT] UIImage: fotoğrafı küçültmek ve JPEG'e çevirmek için

// ┌─ BAĞLANTI HARİTASI: AccountInfoViewModel ───────────────────────────────────
// │ EKRAN    : Views/AccountInfoView (form + fotoğraf) | fotoğrafı çizen: Design/AvatarView
// │ SERVİS   : AccountServicing → AccountService → APIClient → backend AccountController → AccountProfileHandlers → AccountService (C#) → SQL
// │            CityServicing → CityService → GET /api/v1/cities (il seçici)
// │ KURALLAR : e-posta salt okunur | telefon değiştiyse mevcut şifre ister (sunucu da ister; burada erken uyarı)
// │ TEST     : YukumTests/ViewModels/AccountInfoViewModelTests (sahte servisler)
// └──────────────────────────────────────────────────────────────────────
// ZİNCİR (kaydet): Kaydet düğmesi → save() → ön kontrol (ad, telefon, şifre) → service.update → PUT /api/v1/account/me
//   → 200: profile + alanlar sunucunun döndürdüğüyle yenilenir, şifre silinir → View onSaved(ad) → HomeView selamlamadaki adı günceller
//   → 400/409: sunucunun Türkçe mesajı errorMessage'a (APIClient ilk alan hatasını seçer)
// ZİNCİR (fotoğraf): PhotosPicker → baytlar → uploadAvatar(data) → prepareAvatar: 512 px JPEG (arka planda) → service.uploadAvatar (multipart)
//   → yeni avatarUrl profile'a yazılır → AvatarView adres değişince yeni resmi indirir
@MainActor
@Observable
final class AccountInfoViewModel {
    private let service: AccountServicing
    private let cityService: CityServicing
    init(service: AccountServicing = AccountService(), cityService: CityServicing = CityService()) {
        self.service = service
        self.cityService = cityService
    }

    // Sunucudaki son hâl (nil = henüz yüklenmedi)
    var profile: AccountProfile?
    var cities: [City] = []

    // Form alanları (TextField'lar $ ile bağlanır)
    var fullName = ""
    var phone = ""
    var currentPassword = ""   // yalnız telefon değiştiyse görünür
    var cityId: Int?
    var about = ""
    var companyName = ""
    var taxNumber = ""
    var taxOffice = ""

    var errorMessage: String?
    var isSaving = false
    var isPhotoBusy = false

    // Telefon değişti mi? Biçim farkı sayılmaz ("0532 123 45 67" = "+905321234567"): son 10 rakam karşılaştırılır (sunucu da aynı numarayı tek biçime çevirir)
    var phoneChanged: Bool {
        guard let profile else { return false }
        return Self.last10Digits(phone) != Self.last10Digits(profile.phone)
    }

    // Kaydedilmemiş değişiklik var mı? (Kaydet düğmesi yalnız o zaman açık)
    var hasChanges: Bool {
        guard let profile else { return false }
        return makeRequest() != makeRequest(from: profile)
    }

    func load() async {
        errorMessage = nil
        do {
            let loaded = try await service.profile()
            apply(loaded)
        } catch { if let message = error.userMessage { errorMessage = message } }
        // İl listesi gelmezse ekran yine çalışır (il seçici boş görünür); hata mesajı ana bilgiyi örtmesin
        if cities.isEmpty { cities = (try? await cityService.cities()) ?? [] }
    }

    // -> true: kaydedildi | false: hata (errorMessage dolu)
    func save() async -> Bool {
        errorMessage = nil
        guard fullName.trimmingCharacters(in: .whitespaces).count >= 2 else { errorMessage = "Ad soyad en az 2 karakter olmalı."; return false }
        guard Self.last10Digits(phone).count == 10 else { errorMessage = "Geçerli bir cep telefonu numarası gir."; return false }
        if phoneChanged && currentPassword.isEmpty { errorMessage = "Telefonu değiştirmek için mevcut şifreni gir."; return false }

        isSaving = true; defer { isSaving = false }
        do {
            let saved = try await service.update(makeRequest(password: phoneChanged ? currentPassword : nil))
            apply(saved)
            return true
        } catch {
            errorMessage = error.userMessage ?? "Bilgiler kaydedilemedi."
            return false
        }
    }

    // data: PhotosPicker'dan gelen ham fotoğraf (HEIC/JPEG/PNG, birkaç MB olabilir)
    func uploadAvatar(_ data: Data) async {
        errorMessage = nil
        isPhotoBusy = true; defer { isPhotoBusy = false }
        // Task.detached + nonisolated: küçültme ana iş parçacığında yapılmaz → ekran takılmaz (proje varsayılanı MainActor)
        guard let jpeg = await Task.detached(priority: .userInitiated, operation: { Self.prepareAvatar(data) }).value else {
            errorMessage = "Fotoğraf okunamadı."; return
        }
        do {
            let url = try await service.uploadAvatar(jpeg: jpeg)
            if let profile { self.profile = profile.with(avatarUrl: url) }
        } catch { errorMessage = error.userMessage ?? "Fotoğraf yüklenemedi." }
    }

    func removeAvatar() async {
        errorMessage = nil
        isPhotoBusy = true; defer { isPhotoBusy = false }
        do {
            try await service.deleteAvatar()
            if let profile { self.profile = profile.with(avatarUrl: nil) }
        } catch { errorMessage = error.userMessage ?? "Fotoğraf kaldırılamadı." }
    }

    // ─── Yardımcılar ───

    // Fotoğrafı kare kırpar, 512×512'ye küçültür, JPEG (%80) yapar → ~50-150 KB (sunucu sınırı 2 MB)
    // NEDEN telefonda: 12 MP fotoğraf ~3-5 MB; küçültmeden göndermek hem mobil veriyi hem sunucu diskini boşa harcar
    // UIGraphicsImageRenderer [SWIFT/UIKit]: verilen boyutta yeni bir resim çizer | scale = 1: piksel = nokta (Retina katsayısı uygulanmaz)
    nonisolated static func prepareAvatar(_ data: Data, side: CGFloat = 512) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let crop = min(image.size.width, image.size.height)            // kısa kenar: kare kırpma
        let scale = side / crop
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2) // ortalanır, taşan kenarlar kesilir
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize)) // draw: fotoğrafın yönünü (EXIF) de doğru uygular
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    nonisolated static func last10Digits(_ text: String) -> String { String(text.filter(\.isNumber).suffix(10)) }

    // "+905321234567" → "0532 123 45 67" (formda okunur biçim)
    nonisolated static func displayPhone(_ e164: String) -> String {
        let d = Array(last10Digits(e164))
        guard d.count == 10 else { return e164 }
        return "0\(String(d[0..<3])) \(String(d[3..<6])) \(String(d[6..<8])) \(String(d[8..<10]))"
    }

    // Sunucudan gelen hâli forma yazar; şifre her seferinde silinir (bellekte kalmasın)
    private func apply(_ p: AccountProfile) {
        profile = p
        fullName = p.fullName
        phone = Self.displayPhone(p.phone)
        cityId = p.cityId
        about = p.about ?? ""
        companyName = p.companyName ?? ""
        taxNumber = p.taxNumber ?? ""
        taxOffice = p.taxOffice ?? ""
        currentPassword = ""
    }

    // Formdan istek paketi | boş metin → nil (sunucu da boşu null sayar) | Yük Veren alanları Taşımacı'da gönderilmez
    private func makeRequest(password: String? = nil) -> UpdateAccountProfileRequest {
        let shipper = profile?.isShipper ?? false
        func clean(_ s: String) -> String? { let t = s.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t }
        return UpdateAccountProfileRequest(
            fullName: fullName.trimmingCharacters(in: .whitespaces), phone: Self.last10Digits(phone), currentPassword: password,
            cityId: cityId, about: clean(about),
            companyName: shipper ? clean(companyName) : nil, taxNumber: shipper ? clean(taxNumber) : nil, taxOffice: shipper ? clean(taxOffice) : nil)
    }
    // Sunucudaki hâlin aynı biçimdeki paketi (hasChanges karşılaştırması için)
    private func makeRequest(from p: AccountProfile) -> UpdateAccountProfileRequest {
        UpdateAccountProfileRequest(fullName: p.fullName, phone: Self.last10Digits(p.phone), currentPassword: nil, cityId: p.cityId, about: p.about,
                                    companyName: p.companyName, taxNumber: p.taxNumber, taxOffice: p.taxOffice)
    }
}

// Yalnız avatarUrl'i değişmiş kopya (struct alanları let olduğu için)
extension AccountProfile {
    nonisolated func with(avatarUrl: String?) -> AccountProfile {
        AccountProfile(id: id, role: role, fullName: fullName, email: email, phone: phone, avatarUrl: avatarUrl, cityId: cityId, about: about,
                       companyName: companyName, taxNumber: taxNumber, taxOffice: taxOffice,
                       averageRating: averageRating, ratingCount: ratingCount, completedJobCount: completedJobCount)
    }
}
