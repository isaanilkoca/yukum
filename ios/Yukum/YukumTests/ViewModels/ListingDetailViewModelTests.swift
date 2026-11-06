//
//  ListingDetailViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// İlan detay ekranındaki TEKLİF formunun mantığı: tutar doğrulama, paket, hata. Sunucu gerekmez.
@MainActor
struct ListingDetailViewModelTests {

    private func offerVM(myOffer: Double? = nil) -> (ListingDetailViewModel, FakeOfferService) {
        let service = FakeOfferService()
        let base = Sample.listing("L1")
        let listing = Listing(id: base.id, title: base.title, weightKg: base.weightKg, fromCityName: base.fromCityName, fromDistrictName: base.fromDistrictName,
                              toCityName: base.toCityName, toDistrictName: base.toDistrictName, pickupDate: base.pickupDate, budget: base.budget,
                              myOfferAmount: myOffer, myOfferStatus: nil, distanceKm: nil,
                              description: base.description, vehicleType: base.vehicleType, fromCityId: base.fromCityId,
                              fromDistrictId: base.fromDistrictId, toCityId: base.toCityId, toDistrictId: base.toDistrictId, isFavorite: base.isFavorite)
        return (ListingDetailViewModel(listing: listing, service: service), service)
    }

    @Test func offer_rejectsInvalidAmounts_withoutCallingTheServer() async {
        let (vm, service) = offerVM()
        for bad in ["", "abc", "0", "-5", "123123123122"] { // boş, harf, sıfır, eksi, sunucu sınırının üstü
            vm.amountText = bad
            #expect(await vm.submit() == false)
            #expect(vm.errorMessage != nil)
        }
        #expect(service.createCalls.isEmpty)
    }

    @Test func offer_sendsAmountAndTrimmedNote_andReturnsTrue() async {
        let (vm, service) = offerVM()
        vm.amountText = " 1200 "; vm.note = "  yarın yüklerim  "

        #expect(await vm.submit() == true)

        #expect(service.createCalls.first?.listingId == "L1")
        #expect(service.createCalls.first?.body.amount == 1200)
        #expect(service.createCalls.first?.body.note == "yarın yüklerim")
    }

    @Test func offer_emptyNoteIsSentAsNil_andServerErrorsAreShown() async {
        let (vm, service) = offerVM()
        vm.amountText = "500"; vm.note = "   "
        _ = await vm.submit()
        #expect(service.createCalls.first?.body.note == nil)

        service.createResult = .failure(APIError(message: "Bu ilan artık teklif almıyor."))
        #expect(await vm.submit() == false)
        #expect(vm.errorMessage == "Bu ilan artık teklif almıyor.")
    }

    @Test func offer_buttonSaysUpdateWhenAnOfferAlreadyExists() {
        #expect(offerVM().0.buttonTitle == "Teklifi Gönder")
        #expect(offerVM(myOffer: 900).0.buttonTitle == "Teklifi Güncelle")
    }

    // ── Emsal fiyat ──
    @Test func referencePrice_isShownOnlyWhenTheServerHasEnoughData() async {
        let listings = FakeListingService()
        let vm = ListingDetailViewModel(listing: Sample.listing(), service: FakeOfferService(), listingService: listings)
        #expect(vm.referenceText == nil) // yüklenmeden hiçbir şey yok

        await vm.loadReference() // varsayılan sahte cevap: medianAmount nil (yetersiz veri)
        #expect(vm.referenceText == nil)

        listings.priceReferenceResult = .success(PriceReference(medianAmount: 2000, sampleCount: 3))
        await vm.loadReference()
        #expect(vm.referenceText == "Bu rotada emsal fiyat: 2000 ₺ (son 3 iş)")
        // sunucuya ilanın rotası ve araç tipi gitti (Sample: Mersin 33 → İstanbul 34, Truck)
        #expect(listings.priceReferenceCalls.last?.fromCityId == 33)
        #expect(listings.priceReferenceCalls.last?.toCityId == 34)
        #expect(listings.priceReferenceCalls.last?.vehicleType == "Truck")
    }

    @Test func referencePrice_failureIsSilent_andNeverBlocksTheOffer() async {
        let listings = FakeListingService()
        listings.priceReferenceResult = .failure(StubError())
        let vm = ListingDetailViewModel(listing: Sample.listing(), service: FakeOfferService(), listingService: listings)

        await vm.loadReference()

        #expect(vm.referenceText == nil)
        #expect(vm.errorMessage == nil) // hata yazısı çıkmaz: teklif ekranı etkilenmez
    }
}
