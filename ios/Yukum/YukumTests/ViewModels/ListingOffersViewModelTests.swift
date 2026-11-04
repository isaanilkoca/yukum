//
//  ListingOffersViewModelTests.swift
//  YukumTests
//

import Testing
import Foundation
@testable import Yukum

// "Gelen Teklifler" (Yük Veren) ekranının mantığı: karar (kabul/red) ve ilanı yayından kaldırma. Sunucu gerekmez.
@MainActor
struct ListingOffersViewModelTests {

    @Test func incomingOffers_decideCallsTheServerAndReloads() async {
        let service = FakeOfferService()
        service.listingOffersResult = .success([Sample.listingOffer("o1")])
        let vm = ListingOffersViewModel(listing: Sample.listing(), offerService: service, listingService: FakeListingService())

        await vm.decide(Sample.listingOffer("o1"), accept: true)

        #expect(service.decisions.count == 1)
        #expect(service.decisions[0].id == "o1" && service.decisions[0].accept == true)
        #expect(vm.offers.map(\.id) == ["o1"]) // karardan sonra liste yenilendi
    }

    @Test func incomingOffers_aFailedDecisionShowsTheServerMessage() async {
        let service = FakeOfferService()
        service.decideResult = .failure(APIError(message: "Bu teklif için karar zaten verilmiş."))
        let vm = ListingOffersViewModel(listing: Sample.listing(), offerService: service, listingService: FakeListingService())

        await vm.decide(Sample.listingOffer(), accept: false)

        #expect(vm.errorMessage == "Bu teklif için karar zaten verilmiş.")
    }

    @Test func cancelListing_returnsTrueOnSuccess_andFalseWithAMessageOnFailure() async {
        let listings = FakeListingService()
        let vm = ListingOffersViewModel(listing: Sample.listing("L1"), offerService: FakeOfferService(), listingService: listings)

        #expect(await vm.cancelListing() == true)
        #expect(listings.cancelledIds == ["L1"])

        listings.cancelResult = .failure(APIError(message: "Bu ilan zaten tamamlanmış ya da kaldırılmış."))
        #expect(await vm.cancelListing() == false)
        #expect(vm.errorMessage == "Bu ilan zaten tamamlanmış ya da kaldırılmış.")
    }
}
