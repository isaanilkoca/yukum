//
//  ShipperProfileView.swift
//  Yukum
//
//  Yük Veren profili (15 Kasım, 8. adım; kullanıcı: "kullanıcılar birbirinin profilini göremiyor mu?").
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ShipperProfileView ─────────────────────────────────────
// │ VIEWMODEL : ViewModels/ShipperProfileViewModel → GET /api/v1/shippers/{id}
// │ AÇAN      : Views/ListingDetailView (Taşımacı, "İlan sahibi" satırı)
// │ GÖSTERİLEN: fotoğraf (AvatarView), ad, firma, il, üyelik, tamamlanan/açık ilan sayısı, hakkında
// │ GİZLİ     : telefon, e-posta, vergi no — sunucu hiç göndermez; iletişim iş kabul edilince sohbetten
// └──────────────────────────────────────────────────────────────────────

// ⮕ KULLANIM [ShipperProfileView]: ListingDetailView
struct ShipperProfileView: View {
    @State private var viewModel: ShipperProfileViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(shipperId: String) { _viewModel = State(initialValue: ShipperProfileViewModel(shipperId: shipperId)) }

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        ScrollView {
            VStack(spacing: 16) {
                if let message = viewModel.errorMessage { FormMessage(text: message, isError: true) }
                if let p = viewModel.profile {
                    // ÜST: fotoğraf + ad + firma + il/üyelik
                    VStack(spacing: 8) {
                        AvatarView(url: p.avatarUrl, name: p.fullName, size: 96) // ⮕ Design/AvatarView.swift
                        Text(p.fullName).font(.title3.bold()).foregroundStyle(palette.title)
                        if let company = p.companyName { Label(company, systemImage: "building.2.fill").font(.subheadline).foregroundStyle(palette.label) }
                        HStack(spacing: 12) {
                            if let city = p.cityName { Label(city, systemImage: "mappin.and.ellipse") }
                            if let since = MemberSince.text(p.memberSince) { Label("Üyelik: \(since)", systemImage: "calendar") }
                        }
                        .font(.caption).foregroundStyle(palette.label.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                    .themedCard()

                    // SAYILAR: güvenilirlik işareti (Yük Veren puanlanmadığı için puan yok)
                    HStack(spacing: 12) {
                        stat("\(p.completedListingCount)", "Tamamlanan ilan", "checkmark.seal.fill", palette)
                        stat("\(p.openListingCount)", "Yayında ilan", "shippingbox.fill", palette)
                    }

                    if let about = p.about {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hakkında").font(.subheadline.weight(.bold)).foregroundStyle(palette.title)
                            Text(about).foregroundStyle(palette.label)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themedCard()
                    }
                    Label("İletişim bilgileri gizlidir. Teklifin kabul edilince sohbetten yazışabilirsin.", systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(palette.label.opacity(0.7))
                } else if viewModel.errorMessage == nil {
                    LoadingCard()
                }
            }
            .padding(20)
        }
        .background { ScreenBackground() }
        .navigationTitle("Yük Veren Profili")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func stat(_ value: String, _ title: String, _ icon: String, _ palette: Palette) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(palette.accent)
            Text(value).font(.title3.bold()).foregroundStyle(palette.title)
            Text(title).font(.caption).foregroundStyle(palette.label.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .themedCard()
    }
}
