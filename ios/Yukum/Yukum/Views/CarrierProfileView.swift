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
    @State private var viewModel: CarrierProfileViewModel // @State [SWIFT]: ekranın hafızası

    init(carrierId: String) {
        _viewModel = State(initialValue: CarrierProfileViewModel(carrierId: carrierId))
    }

    var body: some View {
        List { // List [SWIFT]: kaydırılabilir satır listesi
            if let message = viewModel.errorMessage { Text(message).foregroundColor(.red) } // hata varsa kırmızı yaz

            if let profile = viewModel.profile { // if let [SWIFT]: nil değilse içini aç | dolana kadar çizilmez
                Section { // Section [SWIFT]: listede gruplu bölüm
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.fullName).font(.title2).bold()
                        Text(RatingText.summary(rating: profile.averageRating, count: profile.ratingCount)).font(.headline).foregroundColor(.orange) // "★ 4.5 (8)" / "Yeni"
                        Text("\(profile.completedJobCount) tamamlanan iş").font(.subheadline).foregroundColor(.secondary)
                    }
                }
                Section("Yorumlar") {
                    if profile.reviews.isEmpty {
                        Text("Henüz yorum yok.").foregroundColor(.secondary)
                    } else {
                        ForEach(profile.reviews, id: \.self) { review in // id: \.self [SWIFT]: öğenin kendisi kimlik (CarrierReview Hashable)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(repeating: "★", count: review.rating) + String(repeating: "☆", count: 5 - review.rating)).foregroundColor(.orange) // String(repeating:count:) [SWIFT]: yazıyı tekrarlar
                                    Spacer()
                                    Text(String(review.createdAt.prefix(10))).font(.caption).foregroundColor(.secondary) // "2026-11-07T..." → ilk 10 karakter
                                }
                                if let comment = review.comment { Text(comment) } // yorum yoksa satır çizilmez
                                Text("\(review.shipperName) · \(review.listingTitle) · \(review.fromCityName) → \(review.toCityName)").font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity) // ProgressView [SWIFT]: dönen çark
            }
        }
        .navigationTitle("Taşımacı Profili")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() } // ekran açılınca yükle
        .refreshable { await viewModel.load() } // aşağı çekince yenile
    }
}
