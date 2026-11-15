//
//  AvatarView.swift
//  Yukum
//
//  Profil fotoğrafı (15 Kasım): yuvarlak resim; fotoğraf yoksa adın baş harfleri.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi
import UIKit   // [SWIFT] UIImage (indirilen baytları resme çevirmek için)

// ┌─ BAĞLANTI HARİTASI: AvatarView.swift ────────────────────────────────────────
// │ GELEN     : Views/AccountInfoView (büyük, düzenlenebilir) | ileride 8. adım profil sayfası, Taşımacı profili
// │ GİDEN     : APIClient.data → GET /api/v1/avatars/{id} (Bearer jeton) → backend AccountController.Avatar → LocalAvatarStorage (disk)
// │ ÖNBELLEK  : AvatarCache (bellek) — aynı adresin içeriği HİÇ değişmez (yeni fotoğraf = yeni id), bir kez indirmek yeter
// └──────────────────────────────────────────────────────────────────────
// NEDEN AsyncImage değil: AsyncImage [SWIFT] isteğe "Authorization: Bearer ..." ekleyemez; fotoğraf ucu jetonsuz 401 döner.
// .task(id:) [SWIFT]: id (adres) değişince eski indirme iptal edilir, yenisi başlar → yeni fotoğraf yüklenince kendiliğinden yenilenir.

// ⮕ KULLANIM [AvatarView]: AccountInfoView
struct AvatarView: View {
    let url: String?   // "/api/v1/avatars/{id}" | nil → baş harfler
    let name: String   // baş harfler için
    var size: CGFloat = 96

    @State private var image: UIImage?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(palette.accent.opacity(0.18))
                Text(initials).font(.system(size: size * 0.36, weight: .bold, design: .rounded)).foregroundStyle(palette.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(palette.accent.opacity(0.5), lineWidth: 2))
        .accessibilityLabel(url == nil ? "Profil fotoğrafı yok" : "Profil fotoğrafı")
        .task(id: url) { await load() }
    }

    // "Ali Veli Yılmaz" → "AY" (ilk ve son kelimenin baş harfi)
    private var initials: String {
        let words = name.split(separator: " ")
        return [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first.map(String.init) }.joined().uppercased(with: Locale(identifier: "tr_TR"))
    }

    private func load() async {
        guard let url else { image = nil; return }
        if let cached = AvatarCache.shared.image(for: url) { image = cached; return }
        // Hata (ağ yok, 404) sessiz: baş harfler görünür, ekran hata yazısıyla dolmaz
        guard let data = try? await APIClient.shared.data(url), let loaded = UIImage(data: data) else { return }
        AvatarCache.shared.store(loaded, for: url)
        image = loaded
    }
}

// Bellek içi fotoğraf önbelleği | NSCache [SWIFT/Foundation]: bellek darlığında kendini boşaltır (uygulamayı çökertmez)
// ⮕ KULLANIM [AvatarCache]: AvatarView
final class AvatarCache {
    static let shared = AvatarCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(for url: String) -> UIImage? { cache.object(forKey: url as NSString) }
    func store(_ image: UIImage, for url: String) { cache.setObject(image, forKey: url as NSString) }
}
