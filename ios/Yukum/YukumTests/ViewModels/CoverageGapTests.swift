//
//  CoverageGapTests.swift
//  YukumTests
//

import Testing
import Foundation
import UIKit
@testable import Yukum

// 15 Kasım: fonksiyon bazlı denetimde testsiz kalan mantık — profil fotoğrafı hazırlama/silme, telefon biçimi, ad değişimi,
// Devam Eden İşler rozeti, teklif kapsamları, iş aşaması yazıları, ilan tarihi çevirisi. Sunucu yok, sahte servisler.
@MainActor
struct CoverageGapTests {

    // MARK: - Hesap Bilgilerim

    @Test func displayPhone_formatsE164AsTurkishMobile_andLeavesOddInputAlone() {
        #expect(AccountInfoViewModel.displayPhone("+905321234567") == "0532 123 45 67")
        #expect(AccountInfoViewModel.displayPhone("05321234567") == "0532 123 45 67") // baştaki 0 tekrarlanmaz
        #expect(AccountInfoViewModel.displayPhone("123") == "123")                   // 10 haneden kısa: dokunulmaz
    }

    @Test func prepareAvatar_cropsToASquare512Jpeg_andRejectsNonImages() throws {
        // 1200x800 yatay görsel → 512x512 kare JPEG
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800), format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let source = renderer.jpegData(withCompressionQuality: 1) { ctx in UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 800)) }

        let prepared = try #require(AccountInfoViewModel.prepareAvatar(source))
        let image = try #require(UIImage(data: prepared))
        #expect(image.size.width == 512 && image.size.height == 512)
        #expect(prepared.count < source.count)                         // küçültüldü
        #expect(prepared.starts(with: [0xFF, 0xD8]))                   // JPEG imzası
        #expect(AccountInfoViewModel.prepareAvatar(Data("resim değil".utf8)) == nil)
    }

    @Test func removeAvatar_clearsThePhoto_andCallsTheServerOnce() async {
        let service = FakeAccountService()
        service.profileResult = .success(FakeAccountService.sampleProfile.with(avatarUrl: "/api/v1/avatars/eski"))
        let vm = AccountInfoViewModel(service: service, cityService: FakeCityService())
        await vm.load()

        await vm.removeAvatar()

        #expect(service.deleteAvatarCalls == 1)
        #expect(vm.profile?.avatarUrl == nil)
        #expect(vm.errorMessage == nil && vm.isPhotoBusy == false)
    }

    // MARK: - Ana ekran

    private func home(_ user: LoginUser, offers: FakeOfferService) -> HomeViewModel {
        HomeViewModel(user: user, listingService: FakeListingService(), offerService: offers,
                      cityService: FakeCityService(), session: FakeSession(), location: FakeLocation(), accountService: FakeAccountService())
    }

    @Test func renameUser_keepsIdAndRole() {
        let vm = home(Sample.carrier, offers: FakeOfferService())
        vm.renameUser("Yeni Ad")
        #expect(vm.user.displayName == "Yeni Ad" && vm.user.id == Sample.carrier.id && vm.user.role == Sample.carrier.role)
    }

    @Test func activeJobCount_countsOnlyAcceptedJobs_forBothRoles() async {
        let offers = FakeOfferService()
        offers.myOffersResult = .success([Sample.carrierOffer("a", status: "Accepted"), Sample.carrierOffer("b", status: "Pending"), Sample.carrierOffer("c", status: "Accepted")])
        offers.historyResult = .success([Sample.historyOffer("x", status: "Accepted"), Sample.historyOffer("y", status: "Completed")])

        let carrier = home(Sample.carrier, offers: offers); await carrier.loadActiveJobCount()
        let shipper = home(Sample.shipper, offers: offers); await shipper.loadActiveJobCount()

        #expect(carrier.activeJobCount == 2)
        #expect(shipper.activeJobCount == 1)
    }

    @Test func activeJobCount_keepsTheOldNumber_whenTheRequestFails() async {
        let offers = FakeOfferService()
        offers.myOffersResult = .success([Sample.carrierOffer("a", status: "Accepted")])
        let vm = home(Sample.carrier, offers: offers)
        await vm.loadActiveJobCount()
        offers.myOffersResult = .failure(StubError())

        await vm.loadActiveJobCount()

        #expect(vm.activeJobCount == 1) // rozet ağ hatasında sıfırlanmaz
    }

    // MARK: - Teklif kapsamları ve iş aşamaları

    @Test func offerScope_splitsPendingActiveAndHistory_withoutOverlap() {
        let statuses = ["Pending", "Accepted", "Rejected", "Withdrawn", "Completed", "Cancelled"]
        for status in statuses {
            let hits = [OfferScope.pending, .active, .history].filter { $0.contains(status: status) }
            #expect(hits.count == 1, "\(status) tam bir kapsama düşmeli")
        }
        let vm = MyOffersViewModel(service: FakeOfferService())
        vm.offers = statuses.enumerated().map { Sample.carrierOffer("o\($0.offset)", status: $0.element) }
        #expect(vm.offers(in: .pending).map(\.status) == ["Pending"])
        #expect(vm.offers(in: .active).map(\.status) == ["Accepted"])
        #expect(vm.offers(in: .history).count == 4)
    }

    @Test func jobStage_titlesAndNextActions_followTheDeliveryOrder() {
        #expect(JobStage.notStarted.title == "Yük bekleniyor")
        #expect(JobStage.delivered.title == "Teslim edildi")
        #expect(JobStage(rawValue: "PickedUp") == .pickedUp)
        #expect(JobStage(rawValue: "Bilinmeyen") == nil)
        let vm = OldOffersViewModel(service: FakeOfferService())
        #expect(vm.stageTitle(Sample.historyOffer(stage: "InTransit")) == "Yolda")
        #expect(vm.stageTitle(Sample.historyOffer(stage: "garip")) == "Yük bekleniyor") // bilinmeyen değer çökmez
    }

    // MARK: - İlan tarihi

    @Test func pickupDate_roundTripsThroughDayString_andFallsBackToToday() {
        func listing(_ day: String) -> Listing {
            Listing(id: "l1", title: "İlan", weightKg: 1000, fromCityName: "Mersin", fromDistrictName: "Mezitli", toCityName: "İstanbul", toDistrictName: "Kadıköy",
                    pickupDate: day, budget: 5000, myOfferAmount: nil, myOfferStatus: nil, distanceKm: nil,
                    description: nil, vehicleType: "Truck", fromCityId: 33, fromDistrictId: 1, toCityId: 34, toDistrictId: 2, isFavorite: false)
        }
        let date = ListingDetailViewModel.pickupDate(of: listing("2026-12-01"))
        #expect(ListingDetailViewModel.dayString(date) == "2026-12-01")
        #expect(ListingDetailViewModel.pickupDate(of: listing("bozuk")) == Calendar.current.startOfDay(for: Date()))
    }

    // MARK: - Araçlarım (kayıt/düzenleme/silme yolları)

    @Test func vehicleSave_checksTypePlateAndCapacity_beforeCallingTheServer() async {
        let service = TrackingVehicleService()
        let vm = VehiclesViewModel(service: service)
        #expect(await vm.save(editing: nil, type: "", plate: "34 A 11", capacity: "", brand: "Volvo", model: "FH", year: "2020") == "Araç türünü seç.")
        #expect(await vm.save(editing: nil, type: "Truck", plate: "  ", capacity: "", brand: "Volvo", model: "FH", year: "2020") == "Plaka zorunlu.")
        #expect(await vm.save(editing: nil, type: "Truck", plate: "34 A 11", capacity: "çok", brand: "Volvo", model: "FH", year: "2020") == "Kapasite sayı olmalı (kg).")
        #expect(await vm.save(editing: nil, type: "Truck", plate: "34 A 11", capacity: "-5", brand: "Volvo", model: "FH", year: "2020") == "Kapasite sayı olmalı (kg).")
        #expect(service.added.isEmpty && service.updated.isEmpty)
    }

    @Test func vehicleSave_addsOrUpdates_withTrimmedValues_andReloads() async {
        let service = TrackingVehicleService()
        let vm = VehiclesViewModel(service: service)

        #expect(await vm.save(editing: nil, type: "Truck", plate: " 34 A 11 ", capacity: "24000", brand: " Volvo ", model: "FH", year: "2020") == nil)
        #expect(service.added.first?.plateNumber == "34 A 11" && service.added.first?.brand == "Volvo" && service.added.first?.capacityKg == 24000)
        #expect(vm.vehicles.count == 1) // eklendikten sonra liste yeniden okundu

        let existing = vm.vehicles[0]
        #expect(await vm.save(editing: existing, type: "Lorry", plate: "34 A 11", capacity: "", brand: "Volvo", model: "FL", year: "2021") == nil)
        #expect(service.updated.first?.id == existing.id && service.updated.first?.body.capacityKg == nil)
    }

    @Test func vehicleSave_andDelete_showTheServerMessage_onFailure() async {
        let service = TrackingVehicleService()
        let vm = VehiclesViewModel(service: service)
        service.fail = APIError(message: "Bu plakayla kayıtlı bir aracın zaten var.")
        #expect(await vm.save(editing: nil, type: "Truck", plate: "34 A 11", capacity: "", brand: "Volvo", model: "FH", year: "2020") == "Bu plakayla kayıtlı bir aracın zaten var.")

        service.fail = nil
        _ = await vm.save(editing: nil, type: "Truck", plate: "34 A 12", capacity: "", brand: "Volvo", model: "FH", year: "2020")
        service.fail = APIError(message: "Araç silinemedi.")
        #expect(await vm.delete(vm.vehicles[0]) == false)
        #expect(vm.errorMessage == "Araç silinemedi." && vm.vehicles.count == 1)

        service.fail = nil
        #expect(await vm.delete(vm.vehicles[0]))
        #expect(vm.vehicles.isEmpty && vm.errorMessage == nil)
    }

    // MARK: - İptal nedenleri

    @Test func cancelReasonPlaceholders_matchEachReason_andHaveAFallback() {
        for reason in CancelReasons.shipper + CancelReasons.carrier {
            #expect(CancelReasons.placeholder(for: reason) != "Kısaca açıkla", "\(reason) için özel ipucu yok")
        }
        #expect(CancelReasons.placeholder(for: "Bilinmeyen") == "Kısaca açıkla")
        #expect(CancelReasons.placeholder(for: "Araç arızası").contains("motor"))
    }
}

// Araç servisi sahtesi: çağrıları kaydeder, istenirse hata verir, eklenenleri listede tutar (load gerçekçi olsun)
final class TrackingVehicleService: VehicleServicing {
    var fail: Error?
    private(set) var list: [Vehicle] = []
    private(set) var added: [VehicleBody] = []
    private(set) var updated: [(id: String, body: VehicleBody)] = []
    func mine() async throws -> [Vehicle] { list }
    func add(_ body: VehicleBody) async throws -> Vehicle {
        if let fail { throw fail }
        added.append(body)
        let v = Vehicle(id: "v\(list.count + 1)", type: body.type, plateNumber: body.plateNumber, capacityKg: body.capacityKg, brand: body.brand, model: body.model, year: body.year)
        list.append(v); return v
    }
    func update(id: String, _ body: VehicleBody) async throws -> Vehicle {
        if let fail { throw fail }
        updated.append((id, body))
        return Vehicle(id: id, type: body.type, plateNumber: body.plateNumber, capacityKg: body.capacityKg)
    }
    func delete(id: String) async throws {
        if let fail { throw fail }
        list.removeAll { $0.id == id }
    }
}
