//
//  ProfileView.swift
//  Yukum
//
//  Profil sayfası (15 Kasım, yönetici planı 8. adım: "İlanlarım, Araçlarım, Teklifler, Beğendiklerim, Hesap").
//  Kullanıcı kararı: üç çizgi menü YOK; hesapla ilgili her şey tek profil sayfasında.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ProfileView ────────────────────────────────────────────
// │ AÇAN      : HomeView sol üst profil fotoğrafı (NavigationLink) | veriler HomeViewModel'den gelir (me, user, unseenCount)
// │ YÜK VEREN : İlanlarım (MyListingsView) · Eski Teklifler (OldOffersView) · Hesap Bilgilerim (AccountInfoView)
// │ TAŞIMACI  : Tekliflerim (MyOffersView, görülmemiş karar rozeti) · Araçlarım (VehiclesView) · Beğendiklerim (FavoritesView) · Hesap Bilgilerim
// │ ALT       : Gizlilik (PrivacyView, sheet) · Hesabı Sil (DeleteAccountView, sheet) · Çıkış
// │ ÇIKIŞ/SİL : HomeView'un verdiği kapanışlar (onSignOut/onDeleted) HomeView'u kapatır → giriş ekranı
// └──────────────────────────────────────────────────────────────────────
// NEDEN veriler parametre: profil başlığı (fotoğraf, ad) ana ekrandaki fotoğrafla AYNI kaynaktan (HomeViewModel.me) gelir;
//   Hesap Bilgilerim'de değişiklik → onRename → HomeViewModel yeniden okur → iki ekran birlikte güncellenir (iki ayrı istek/kopya yok).

// ⮕ KULLANIM [ProfileView]: HomeView
struct ProfileView: View {
    let isShipper: Bool
    let name: String
    let me: AccountProfile?          // nil → yükleniyor ya da ağ yok (baş harfler gösterilir)
    let unseenCount: Int             // Taşımacı: görülmemiş teklif kararı
    var activeJobCount: Int = 0      // 15 Kasım: Devam Eden İşler rozeti (kabul edilmiş, bitmemiş iş sayısı)
    var onRename: (String) -> Void   // Hesap Bilgilerim kaydedince
    var onRefresh: () async -> Void  // profil göründükçe HomeViewModel.me tazelenir (fotoğraf değişti mi)
    var onSignOut: () async -> Void
    var onDeleted: () -> Void

    @State private var showPrivacy = false
    @State private var showDeleteAccount = false
    @State private var signingOut = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        List {
            header(palette).listRowBackground(Color.clear).listRowSeparator(.hidden)

            // ROL SATIRLARI | NavigationLink [SWIFT]: basınca ekranı bu yığına iter (Geri kendiliğinden gelir)
            Section {
                // 15 Kasım: DEVAM EDEN İŞLER en üstte (kabul edilmiş, teslim/tamamlanmamış işler; aşama, iptal talebi, sohbet burada)
                //   Eski Teklifler / Geçmiş yalnız SONUÇLANANLAR | Tekliflerim yalnız BEKLEYENLER ("Görüşülüyor" etiketiyle)
                if isShipper {
                    link("Devam Eden İşler", "shippingbox.and.arrow.backward.fill", palette, badge: activeJobCount) { OldOffersView(scope: .active) }
                    link("İlanlarım", "shippingbox.fill", palette) { MyListingsView() }
                    link("Eski Teklifler", "clock.arrow.circlepath", palette) { OldOffersView(scope: .history) }
                } else {
                    link("Devam Eden İşler", "shippingbox.and.arrow.backward.fill", palette, badge: activeJobCount) { MyOffersView(scope: .active) }
                    link("Tekliflerim", "tray.full.fill", palette, badge: unseenCount) { MyOffersView(scope: .pending) }
                    link("Geçmiş", "clock.arrow.circlepath", palette) { MyOffersView(scope: .history) }
                    link("Araçlarım", "truck.box.fill", palette) { VehiclesView() }
                    link("Beğendiklerim", "heart.fill", palette) { FavoritesView() }
                }
                link("Hesap Bilgilerim", "person.crop.circle.fill", palette) { AccountInfoView(onSaved: onRename) }
            }

            // HESAP EYLEMLERİ (önceden ana ekranın altındaki kapsül satırı)
            Section {
                Button { showPrivacy = true } label: { rowLabel("Gizlilik ve KVKK", "hand.raised.fill", palette.title, palette) }
                    .themedRow()
                Button { showDeleteAccount = true } label: { rowLabel("Hesabı Sil", "person.crop.circle.badge.xmark", palette.danger, palette) }
                    .themedRow()
                Button {
                    Task { signingOut = true; await onSignOut() } // ⮕ HomeView: HomeViewModel.signOut → POST /api/v1/auth/logout, sonra dismiss
                } label: { rowLabel("Çıkış Yap", "rectangle.portrait.and.arrow.right", palette.accent, palette) }
                    .themedRow()
                    .disabled(signingOut)
            }
        }
        .listStyle(.plain)
        .themedScreen()
        .busyIndicator(signingOut)
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await onRefresh() } } // .onAppear [SWIFT]: Hesap Bilgilerim'den GERİ dönünce de çalışır → yeni fotoğraf hemen görünür
        .sheet(isPresented: $showPrivacy) { PrivacyView() } // ⮕ Views/PrivacyView
        .sheet(isPresented: $showDeleteAccount) { DeleteAccountView(onDeleted: onDeleted) } // ⮕ Views/DeleteAccountView (şifre onayı orada)
    }

    // BAŞLIK: fotoğraf + ad + rol | Taşımacı: puan ve tamamlanan iş (salt okunur)
    private func header(_ palette: Palette) -> some View {
        HStack(spacing: 16) {
            AvatarView(url: me?.avatarUrl, name: name, size: 72) // ⮕ Design/AvatarView.swift
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.title3.bold()).foregroundStyle(palette.title)
                Text(isShipper ? "Yük Veren" : "Taşımacı").font(.subheadline).foregroundStyle(palette.label.opacity(0.75))
                if !isShipper, let me {
                    Text(RatingText.summary(rating: me.averageRating ?? 0, count: me.ratingCount ?? 0)).font(.caption.bold()).foregroundStyle(palette.accent)
                    Label("\(me.completedJobCount ?? 0) tamamlanan iş", systemImage: "flag.checkered").font(.caption).foregroundStyle(palette.label.opacity(0.75))
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // Tek tip satır: simge + başlık (+ rozet) + ok | destination: açılacak ekran
    private func link<Destination: View>(_ title: String, _ icon: String, _ palette: Palette, badge: Int = 0,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            HStack {
                rowLabel(title, icon, palette.title, palette)
                if badge > 0 {
                    Text("\(badge)").font(.caption2.bold()).foregroundStyle(palette.buttonText)
                        .padding(.horizontal, 7).padding(.vertical, 3).background(palette.accent, in: .capsule)
                }
            }
        }
        .themedRow()
    }

    private func rowLabel(_ title: String, _ icon: String, _ color: Color, _ palette: Palette) -> some View {
        Label { Text(title).foregroundStyle(color) } icon: { Image(systemName: icon).foregroundStyle(palette.accent) }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
