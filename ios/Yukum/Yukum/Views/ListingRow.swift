//
//  ListingRow.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import SwiftUI

// ┌─ BAĞLANTI HARİTASI: ListingRow (ilan satırı) ──────────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ GİRDİ                    →  listing: Listing — HomeView'daki List her satır için verir (ViewModel yok: saf çizim)
// │ Gösterdikleri            →  başlık, "Mersin → İstanbul", kg · tarih, Taşımacı için "Teklifin: ... Beklemede", "📍 X km uzaklıkta" (Listing.distanceKm)
// └──────────────────────────────────────────────────────────────────────

struct ListingRow: View {
    
    // BU EKRAN PARÇASI: listedeki TEK ilan satırı. Yük Veren ve Taşımacı listeleri aynı satırı kullanır (kod tekrarı olmasın).
    // BAĞLANTI: Views/HomeView.swift, List içinde ListingRow(listing: listing) diye çağırır | kalıp: Models/Listings/ → struct Listing
    
    let listing : Listing
    
    var body: some View {
        VStack(alignment:.leading ,spacing: 6) { // alt alta, sola hizalı | spacing: satırlar arası boşluk
            Text(listing.title).font(.headline)  // başlık: kalın ve büyük
            Text("\(listing.fromCityName) -> \(listing.toCityName)").font(.subheadline) // "Mersin → İstanbul" | \( ) = yazının içine değişken koyar
            Text("\(listing.weightKg) kg . \(listing.pickupDate)").font(.caption).foregroundColor(.secondary) // küçük gri yazı
            
            if let km = listing.distanceKm { // if let: nil değilse içine gir | yalnız "Yakınımdakiler" açıkken (konum gönderilince) dolu gelir
            // Int(km): 12.4 → 12, ondalığı atar | "Mersin'e uzaklık" değil, ilanın kalkış noktasına olan mesafedir
            Text("📍 \(Int(km)) km uzaklıkta").font(.caption).foregroundColor(.blue) // küçük mavi yazı
            }
            
            if let amount = listing.myOfferAmount { // if let: nil değilse içine gir | yalnız teklif verdiysek (Taşımacı listesinde) dolu gelir
            // Text(...) + renk: durum yazısı | ?: kısa if | "Rejected" ise kırmızı, değilse turuncu (beklemede)
            Text("Teklifin: \(Int(amount)) ₺ · \(listing.myOfferStatus == "Rejected" ? "Reddedildi" : "Beklemede")")
            .font(.caption).foregroundColor(listing.myOfferStatus == "Rejected" ? .red : .orange) // küçük renkli yazı
                
        }

        }.padding(.vertical,4)  // satırın üstüne ve altına 4 nokta boşluk

    }
}

