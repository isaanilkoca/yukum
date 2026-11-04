//
//  ListingRow.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import SwiftUI // import SwiftUI [SWIFT]: ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ListingRow (ilan satırı) ──────────────────────────────────
// │ EKRANDAKİ ŞEY  →  VIEWMODEL  →  SERVİS  →  API  →  MODEL   (ok yönü: ekrandan arka plana)
// │ GİRDİ                    →  listing: Listing — HomeView'daki List her satır için verir (ViewModel yok: saf çizim)
// │ Gösterdikleri            →  başlık, "Mersin → İstanbul", kg · tarih, Taşımacı için "Teklifin: ... Beklemede", "📍 X km uzaklıkta" (Listing.distanceKm)
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [ListingRow]: kullanır: HomeView › body
struct ListingRow: View { // View [SWIFT]: bu bir ekran/görünüm
    
    // BU EKRAN PARÇASI: listedeki TEK ilan satırı. Yük Veren ve Taşımacı listeleri aynı satırı kullanır (kod tekrarı olmasın).
    // BAĞLANTI: Views/HomeView.swift, List içinde ListingRow(listing: listing) diye çağırır | kalıp: Models/Listings/ → struct Listing
    
    // ⮕ KULLANIM [listing]: okur: ListingRow › body
    let listing : Listing
    
    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        VStack(alignment:.leading ,spacing: 6) { // alt alta, sola hizalı | spacing: satırlar arası boşluk | VStack [SWIFT]: elemanları alt alta dizer
            Text(listing.title).font(.headline)  // başlık: kalın ve büyük | Text [SWIFT]: yazı gösterir | .font [SWIFT]: yazı boyutu/stili
            Text("\(listing.fromCityName) -> \(listing.toCityName)").font(.subheadline) // "Mersin → İstanbul" | \( ) = yazının içine değişken koyar
            Text("\(listing.weightKg) kg . \(listing.pickupDate)").font(.caption).foregroundColor(.secondary) // küçük gri yazı | .foregroundColor [SWIFT]: yazı rengi
            
            if let km = listing.distanceKm { // if let: nil değilse içine gir | yalnız "Yakınımdakiler" açıkken (konum gönderilince) dolu gelir
            // Int(km): 12.4 → 12, ondalığı atar | "Mersin'e uzaklık" değil, ilanın kalkış noktasına olan mesafedir
            Text("📍 \(Int(km)) km uzaklıkta").font(.caption).foregroundColor(.blue) // küçük mavi yazı
            }
            
            if let amount = listing.myOfferAmount { // if let: nil değilse içine gir | yalnız teklif verdiysek (Taşımacı listesinde) dolu gelir
            // Text(...) + renk: durum yazısı | ?: kısa if | "Rejected" ise kırmızı, değilse turuncu (beklemede)
            Text("Teklifin: \(Int(amount)) ₺ · \(listing.myOfferStatus == "Rejected" ? "Reddedildi" : "Beklemede")")
            .font(.caption).foregroundColor(listing.myOfferStatus == "Rejected" ? .red : .orange) // küçük renkli yazı
                
        }

        }.padding(.vertical,4)  // satırın üstüne ve altına 4 nokta boşluk | .padding [SWIFT]: etrafında boşluk bırakır

    }
}

