//
//  OfferVehicleTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// 15 Kasım: teklifte araç + teslim tarihi, Yük Veren'in teklif sıralaması, araç bilgisi zorunluluğu, Taşımacı filtresi
@MainActor
struct OfferVehicleTests {

    private func offer(_ id: String, _ amount: Double, delivery: String? = nil, year: Int? = nil, type: String? = nil,
                       rating: Double = 0, count: Int = 0, jobs: Int? = nil) -> ListingOffer {
        var o = ListingOffer(id: id, carrierName: id, amount: amount, note: nil, status: "Pending", carrierId: "c" + id,
                             carrierRating: rating, carrierRatingCount: count)
        o.estimatedDeliveryDate = delivery; o.vehicleYear = year; o.vehicleType = type; o.carrierCompletedJobCount = jobs
        return o
    }

    @Test func shipperCanSortOffersByEverything_andOffersWithoutInfoGoLast() {
        let list = [offer("a", 3000, delivery: "2026-12-05", year: 2015, type: "Truck", rating: 4.0, count: 3, jobs: 10),
                    offer("b", 1000, delivery: "2026-12-10", year: 2022, type: "Pickup", rating: 5.0, count: 1, jobs: 2),
                    offer("c", 2000)] // eski teklif: araç/tarih yok
        let ids = { (s: OfferSort) in ListingOffersViewModel.sorted(list, by: s).map(\.id) }
        #expect(ids(.priceAsc) == ["b", "c", "a"])
        #expect(ids(.priceDesc) == ["a", "c", "b"])
        #expect(ids(.deliverySoonest) == ["a", "b", "c"])
        #expect(ids(.vehicleNewest) == ["b", "a", "c"])
        #expect(ids(.rating) == ["b", "a", "c"])
        #expect(ids(.experience) == ["a", "b", "c"])
        #expect(ids(.vehicleType) == ["b", "a", "c"]) // Kamyonet < Tır (Türkçe alfabe), bilgisi olmayan sonda
    }

    @Test func offerSendsTheChosenVehicleAndDeliveryDate() async {
        let offers = FakeOfferService(), vehicles = FakeVehicleService()
        vehicles.list = [Vehicle(id: "v1", type: "Truck", plateNumber: "34 A 11", capacityKg: nil, brand: "Volvo", model: "FH", year: 2020),
                         Vehicle(id: "v2", type: "Car", plateNumber: "34 B 22", capacityKg: nil, brand: "Fiat", model: "Egea", year: 2021)]
        let vm = ListingDetailViewModel(listing: Sample.listing(), service: offers, vehicleService: vehicles) // yükleme 2026-12-01
        await vm.loadVehicles()
        #expect(vm.selectedVehicleId == "v1")
        vm.selectedVehicleId = "v2"; vm.amountText = "900"

        #expect(await vm.submit())
        #expect(offers.createCalls.first?.body.vehicleId == "v2")
        #expect(offers.createCalls.first?.body.estimatedDeliveryDate == "2026-12-02") // varsayılan: yüklemeden 1 gün sonra
    }

    @Test func aVehicleWithoutBrandModelYear_cannotBeUsedForAnOffer() async {
        let offers = FakeOfferService(), vehicles = FakeVehicleService()
        vehicles.list = [Vehicle(id: "old", type: "Truck", plateNumber: "34 A 11", capacityKg: nil)] // eski kayıt
        let vm = ListingDetailViewModel(listing: Sample.listing(), service: offers, vehicleService: vehicles)
        await vm.loadVehicles(); vm.amountText = "900"

        #expect(await vm.submit() == false)
        #expect(vm.errorMessage?.contains("Araçlarım") == true) // "Araçlarım'a git" düğmesi çıkar
        #expect(offers.createCalls.isEmpty)
    }

    @Test func vehicleSave_requiresBrandModelAndAValidYear() async {
        let vm = VehiclesViewModel(service: FakeVehicleService())
        #expect(await vm.save(editing: nil, type: "Truck", plate: "34 A 11", capacity: "", brand: "", model: "FH", year: "2020") == "Marka zorunlu.")
        #expect(await vm.save(editing: nil, type: "Truck", plate: "34 A 11", capacity: "", brand: "Volvo", model: "", year: "2020") == "Model zorunlu.")
        #expect(await vm.save(editing: nil, type: "Truck", plate: "34 A 11", capacity: "", brand: "Volvo", model: "FH", year: "1800")?.hasPrefix("Model yılı") == true)
        #expect(await vm.save(editing: nil, type: "Truck", plate: "34 A 11", capacity: "", brand: "Volvo", model: "FH", year: "2020") == nil)
    }

    @Test func carrierFilter_sendsPickupSortAndVehicleMatch() {
        var f = OpenListingsFilter(); f.sort = .pickupSoonest; f.matchMyVehicles = true
        let q = f.queryItems(page: 1, pageSize: 20, lat: nil, lon: nil)
        #expect(q.contains(URLQueryItem(name: "sort", value: "PickupSoonest")))
        #expect(q.contains(URLQueryItem(name: "matchMyVehicles", value: "true")))
        #expect(f.extraCount == 1) // sıralama filtre sayısına girmez (ayrı menü)
    }
}

// VehicleServicing sahtesi (15 Kasım)
final class FakeVehicleService: VehicleServicing {
    var list: [Vehicle] = []
    func mine() async throws -> [Vehicle] { list }
    func add(_ body: VehicleBody) async throws -> Vehicle { Vehicle(id: "new", type: body.type, plateNumber: body.plateNumber, capacityKg: body.capacityKg) }
    func update(id: String, _ body: VehicleBody) async throws -> Vehicle { Vehicle(id: id, type: body.type, plateNumber: body.plateNumber, capacityKg: body.capacityKg) }
    func delete(id: String) async throws {}
}
