//
//  ListingRow.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import SwiftUI

struct ListingRow: View {
    
    // BU EKRAN PARÇASI: listedeki TEK ilan satırı. Yük Veren ve Taşımacı listeleri aynı satırı kullanır (kod tekrarı olmasın).
    // BAĞLANTI: View/HomeView.swift, List içinde ListingRow(listing: listing) diye çağırır | kalıp: Network/ListingRequest.swift → struct Listing
    
    let listing : Listing
    
    var body: some View {
        VStack(alignment:.leading ,spacing: 6) { // alt alta, sola hizalı | spacing: satırlar arası boşluk
            Text(listing.title).font(.headline)  // başlık: kalın ve büyük
            Text("\(listing.fromCityName) -> \(listing.toCityName)").font(.subheadline) // "Mersin → İstanbul" | \( ) = yazının içine değişken koyar
            Text("\(listing.weightKg) kg . \(listing.pickupDate)").font(.caption).foregroundColor(.secondary) // küçük gri yazı
        
        }.padding(.vertical,4)  // satırın üstüne ve altına 4 nokta boşluk

    }
}

