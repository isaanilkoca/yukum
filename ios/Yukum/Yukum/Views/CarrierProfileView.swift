//
//  CarrierProfileView.swift
//  Yukum
//

import SwiftUI

// ┌─ BAĞLANTI HARİTASI: CarrierProfileView ──────────────────────────────────────────
// │ VIEWMODEL : ViewModels/CarrierProfileViewModel | açan: ListingOffersView / OldOffersView (navigationDestination)
// │ Başlık (ad, ★ ortalama, tamamlanan iş)  →  viewModel.profile  →  ReviewService  →  GET /api/v1/carriers/{id}  →  CarrierProfile
// │ Yorumlar (rota + yorum)                  →  profile.reviews (CarrierReview)
// └──────────────────────────────────────────────────────────────────────

struct CarrierProfileView: View {
    @State private var viewModel: CarrierProfileViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(carrierId: String) {
        _viewModel = State(initialValue: CarrierProfileViewModel(carrierId: carrierId))
    }

    // GÖRÜNÜM (15 Kasım, L tasarım): üstte profil kartı (baş harf rozeti, puan, tamamlanan iş), altında yorum kartları. İŞLEV DEĞİŞMEDİ.
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        List {
            if let message = viewModel.errorMessage { FormMessage(text: message, isError: true).listRowBackground(Color.clear).listRowSeparator(.hidden) }
            if let profile = viewModel.profile {
                HStack(spacing: 14) {
                    AvatarView(url: profile.avatarUrl, name: profile.fullName, size: 64) // 15 Kasım (8. adım): baş harf rozeti yerine fotoğraf (yoksa baş harfler) ⮕ Design/AvatarView.swift
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.fullName).font(.title3.bold()).foregroundStyle(palette.title)
                        Text(RatingText.summary(rating: profile.averageRating, count: profile.ratingCount)).font(.subheadline.bold()).foregroundStyle(palette.accent)
                        Label("\(profile.completedJobCount) tamamlanan iş", systemImage: "flag.checkered").font(.caption).foregroundStyle(palette.label.opacity(0.75))
                        // 15 Kasım: il + üyelik (sunucu sona ekledi; eski cevapta yoksa satır çizilmez)
                        HStack(spacing: 10) {
                            if let city = profile.cityName { Label(city, systemImage: "mappin.and.ellipse") }
                            if let since = MemberSince.text(profile.memberSince) { Label("Üyelik: \(since)", systemImage: "calendar") }
                        }
                        .font(.caption).foregroundStyle(palette.label.opacity(0.75))
                    }
                }
                .themedRow()

                if let about = profile.about { // Hesap Bilgilerim'de yazdığı tanıtım
                    Text(about).foregroundStyle(palette.label).themedRow()
                }

                // ARAÇLARI (15 Kasım, kullanıcı: "ilan veren profildeki araçları görebilsin, daha kaliteli araç isteyebilir")
                //   tür · marka model · yıl · kapasite | PLAKA gösterilmez (sunucu göndermez) | en yeni model üstte (sunucu sıralar)
                if let vehicles = profile.vehicles, !vehicles.isEmpty {
                    Text("Araçları").font(.subheadline.weight(.bold)).foregroundStyle(palette.title)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    ForEach(vehicles, id: \.self) { v in
                        HStack(spacing: 12) {
                            Image(systemName: v.type == "Car" ? "car.fill" : "truck.box.fill").foregroundStyle(palette.accent).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.typeTitle).font(.subheadline.bold()).foregroundStyle(palette.title)
                                let name = [v.brand, v.model].compactMap { $0 }.joined(separator: " ")
                                Text([name.isEmpty ? nil : name, v.year.map { "\($0) model" }].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(palette.label)
                            }
                            Spacer()
                            if let kg = v.capacityKg { Text("\(kg.formatted()) kg").font(.caption.weight(.semibold)).foregroundStyle(palette.label.opacity(0.75)) }
                        }
                        .themedRow()
                    }
                }

                Text("Yorumlar").font(.subheadline.weight(.bold)).foregroundStyle(palette.title)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                if profile.reviews.isEmpty {
                    EmptyStateCard(icon: "star", title: "Henüz yorum yok.").listRowBackground(Color.clear).listRowSeparator(.hidden)
                } else {
                    ForEach(profile.reviews, id: \.self) { review in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { i in Image(systemName: i <= review.rating ? "star.fill" : "star").font(.caption) }
                                }
                                .foregroundStyle(palette.accent)
                                Spacer()
                                Text(RouteCard.trDate(review.createdAt)).font(.caption).foregroundStyle(palette.label.opacity(0.65))
                            }
                            if let comment = review.comment { Text(comment).foregroundStyle(palette.title) }
                            Text("\(review.shipperName) · \(review.listingTitle) · \(review.fromCityName) → \(review.toCityName)").font(.caption).foregroundStyle(palette.label.opacity(0.65))
                        }
                        .themedRow()
                    }
                }
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .navigationTitle("Taşımacı Profili")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
