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
            // 15 Kasım (L tasarım): "Mersin -> İstanbul" düz yazısı yerine temanın rota satırı (ilçeleriyle) | tarih "28.11.2026" biçiminde
            RouteLine(from: listing.fromCityName, fromDistrict: listing.fromDistrictName, to: listing.toCityName, toDistrict: listing.toDistrictName) // ⮕ Design/FormStyle.swift
            Text("\(listing.weightKg) kg · \(RouteCard.trDate(listing.pickupDate))\(listing.budget.map { " · \(Int($0)) ₺" } ?? "")").font(.caption).foregroundColor(.secondary) // küçük gri yazı | bütçe varsa sonda
            
            if let km = listing.distanceKm { // if let: nil değilse içine gir | yalnız "Yakınımdakiler" açıkken (konum gönderilince) dolu gelir
            // Int(km): 12.4 → 12, ondalığı atar | "Mersin'e uzaklık" değil, ilanın kalkış noktasına olan mesafedir
            Text("📍 \(Int(km)) km uzaklıkta").font(.caption).foregroundColor(.orange) // küçük turuncu yazı (15 Kasım: mavi temaya uymuyordu)
            }
            
            if let amount = listing.myOfferAmount { // if let: nil değilse içine gir | yalnız teklif verdiysek (Taşımacı listesinde) dolu gelir
            // Text(...) + renk: durum yazısı | ?: kısa if | "Rejected" ise kırmızı, değilse turuncu (beklemede)
            Text("Teklifin: \(Int(amount)) ₺ · \(listing.myOfferStatus == "Rejected" ? "Reddedildi" : "Beklemede")")
            .font(.caption).foregroundColor(listing.myOfferStatus == "Rejected" ? .red : .orange) // küçük renkli yazı
                
        }

        }.padding(.vertical,4)  // satırın üstüne ve altına 4 nokta boşluk | .padding [SWIFT]: etrafında boşluk bırakır

    }
}


// ─── ROTA KARTI (Taşımacı tarafı, L tasarım) ───────────────────────────────────────
// BU GÖRÜNÜM: Taşımacı'nın ilan kartı = bir ROTA. Üstte başlık (+ bütçe, favori), ortada Nereden ——🚚—— Nereye (ilçeleriyle),
//   altta kg / tarih / mesafe çipleri, teklif verdiyse durum rozeti. Yarı şeffaf zemin: arkadaki sahne görünür.
// NEDEN burada (15 Kasım): önce HomeView'ın içindeydi (carrierCard); Favoriler ve İlan Detayı da aynı kartı kullansın diye ayrı görünüm oldu.
//   ListingRow'un yanında: ikisi de "ilan satırı"; ListingRow Yük Veren tarafında ve eski ekranlarda kullanılmaya devam ediyor.
// showsChevron: listede ">" oku (basılabilir) | detay ekranında gizli (zaten içindesin)
// ⮕ KULLANIM [RouteCard]: kullanır: HomeView › carrierHome, FavoritesView › body, ListingDetailView › body
struct RouteCard: View {
    let listing: Listing
    var showsChevron = true
    var favorite: Bool? = nil // detay ekranı canlı kalp durumunu verir (kalbe basınca kart da güncellensin) | nil → listing.isFavorite
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(listing.title).font(.headline).foregroundStyle(palette.title).lineLimit(1)
                Spacer(minLength: 4)
                if favorite ?? listing.isFavorite { Image(systemName: "heart.fill").font(.footnote).foregroundStyle(palette.accent) } // ⮕ Listing.isFavorite
                if let budget = listing.budget { // bütçe girildiyse: Taşımacı için en önemli sayı → turuncu, kalın
                    Text("\(Int(budget)) ₺").font(.subheadline.bold()).foregroundStyle(palette.accent)
                }
                if showsChevron { Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(palette.accent) }
            }

            // ROTA: iki uç arasında kesik çizgili yol, ortasında tır
            HStack(spacing: 8) {
                end(listing.fromCityName, listing.fromDistrictName, .leading, palette)
                ZStack {
                    RouteDash().stroke(palette.label.opacity(0.45), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5])) // dash [SWIFT]: 6 nokta çizgi, 5 boşluk
                    Image(systemName: "truck.box.fill").font(.caption).foregroundStyle(palette.accent)
                        .padding(5).background(palette.cardSurface, in: .circle) // çizgiyi tırın altında keser
                }
                .frame(maxWidth: .infinity).frame(height: 24)
                end(listing.toCityName, listing.toDistrictName, .trailing, palette)
            }

            HStack(spacing: 6) {
                chip("scalemass.fill", "\(listing.weightKg) kg", palette)
                chip("calendar", Self.trDate(listing.pickupDate), palette)
                if let km = listing.distanceKm { chip("location.fill", "\(Int(km)) km", palette) } // yalnız Yakınımdakiler açıkken dolu
            }

            if let amount = listing.myOfferAmount { // teklif verdiysem: durum rozeti | "Rejected" kırmızı, değilse turuncu (ListingRow ile aynı kural)
                let rejected = listing.myOfferStatus == "Rejected"
                Label("Teklifin \(Int(amount)) ₺ · \(rejected ? "Reddedildi" : "Beklemede")", systemImage: rejected ? "xmark.circle.fill" : "hourglass")
                    .font(.caption.bold())
                    .foregroundStyle(rejected ? Color.red : palette.accent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background((rejected ? Color.red : palette.accent).opacity(0.14), in: .capsule)
            }
        }
        .padding(14)
        .padding(.leading, 4) // soldaki turuncu şeride yer
        .background(palette.cardSurface.opacity(0.88), in: .rect(cornerRadius: 16)) // 15 Kasım: 0,62 → 0,88 (okunurluk)
        .overlay(alignment: .leading) { // sol kenarda turuncu şerit: yol kenar çizgisi gibi
            Capsule().fill(palette.accent).frame(width: 4).padding(.vertical, 14).padding(.leading, 6)
        }
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(palette.cardBorder))
    }

    // Rota ucu: il kalın, ilçe küçük | uzun adlar biraz küçülür | maxWidth: ortadaki yola yer kalsın
    private func end(_ city: String, _ district: String, _ alignment: HorizontalAlignment, _ palette: Palette) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(city).font(.subheadline.bold()).foregroundStyle(palette.title)
            Text(district).font(.caption2).foregroundStyle(palette.label.opacity(0.7))
        }
        .lineLimit(1).minimumScaleFactor(0.8) // [SWIFT] sığmazsa yazıyı %80'e kadar küçült
        .frame(maxWidth: 112, alignment: alignment == .leading ? .leading : .trailing)
    }

    // Bilgi çipi: simge + kısa yazı, kapsül zemin
    private func chip(_ icon: String, _ text: String, _ palette: Palette) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold)).foregroundStyle(palette.label.opacity(0.85))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(palette.fieldSurface, in: .capsule)
    }

    // "2026-10-31" → "31.10.2026" | beklenmeyen biçimde gelirse olduğu gibi gösterir
    // ⮕ KULLANIM [trDate]: kullanır: RouteCard › body, ListingDetailView
    static func trDate(_ text: String) -> String {
        let parts = text.prefix(10).split(separator: "-") // prefix(10): saat eklenmiş gelse de yalnız tarih kısmı
        guard parts.count == 3, parts[0].count == 4 else { return text }
        return "\(parts[2]).\(parts[1]).\(parts[0])"
    }
}

// Rota kartındaki yol çizgisi: yüksekliğin ortasından soldan sağa düz çizgi (kesik görünümü stroke'un dash'i verir)
// ⮕ KULLANIM [RouteDash]: kullanır: RouteCard
private struct RouteDash: Shape { // Shape [SWIFT]: kodla çizilen şekil
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
