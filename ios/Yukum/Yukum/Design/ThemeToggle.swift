//
//  ThemeToggle.swift
//  Yukum
//
//  Uygulama içi görünüm seçimi: Sistem / Açık / Koyu. Seçim telefonda saklanır, tüm uygulamaya tek yerden uygulanır.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ThemeToggle.swift ─────────────────────────────────────────
// │ GELEN     : App/YukumApp.swift → @AppStorage(AppTheme.storageKey) okur, .preferredColorScheme ile TÜM pencereye uygular
// │             Views/LoginView.swift (sağ üst köşe) | Views/HomeView.swift (üst çubuk, iki rol) → ThemeToggle() düğmesi
// │ GİDEN     : yok (UserDefaults: @AppStorage)
// │ ETKİSİ    : Palette(isDark:) her ekranda colorScheme'den türer → seçim değişince renkler kendiliğinden değişir.
// │             Koyu seçilirse giriş ekranında sahne spotu çalışır (Design/TapedBoxBackground, yalnız koyu mod).
// └──────────────────────────────────────────────────────────────────────
//
// ZİNCİR: ThemeToggle menüsünden seçim → @AppStorage("appTheme") değişir (telefonda saklanır)
//   → YukumApp aynı anahtarı okuduğu için yeniden çizilir → .preferredColorScheme(theme.colorScheme)
//   → tüm ekranlar (açık sayfalar dahil) yeni modda çizilir.
// NEDEN @AppStorage [SWIFT]: UserDefaults'a bağlı değişken; değeri uygulama kapanıp açılınca da kalır ve aynı anahtarı
//   okuyan HER görünüm değişikliği anında görür (ayrıca haber vermeye gerek yok).

// Görünüm seçenekleri | rawValue: telefonda saklanan yazı
// ⮕ KULLANIM [AppTheme]: kullanır: YukumApp › body, ThemeToggle
enum AppTheme: String, CaseIterable {
    case system, light, dark

    static let storageKey = "appTheme" // UserDefaults anahtarı (YukumApp ve ThemeToggle aynı anahtarı okur)

    var title: String { // menüde görünen ad
        switch self {
        case .system: return "Sistem"
        case .light: return "Açık"
        case .dark: return "Koyu"
        }
    }
    var icon: String { // SF Symbols simgesi
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    // nil = telefonun ayarını izle | ColorScheme [SWIFT]: açık/koyu
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// BU GÖRÜNÜM: küçük yuvarlak düğme; basınca 3 seçenekli menü açılır. Simgesi seçili modu gösterir.
// Menu [SWIFT]: basınca seçenek listesi açan düğme | Picker menünün içinde: seçili olanın yanında tik çıkar.
// ⮕ KULLANIM [ThemeToggle]: kullanır: LoginView › body, HomeView › toolbar
struct ThemeToggle: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system // [SWIFT] telefonda saklanan seçim

    var body: some View {
        Menu {
            Picker("Görünüm", selection: $theme) {
                ForEach(AppTheme.allCases, id: \.self) { option in
                    Label(option.title, systemImage: option.icon).tag(option)
                }
            }
        } label: {
            Image(systemName: theme.icon)
                .accessibilityLabel("Görünüm: \(theme.title)") // VoiceOver okusun
        }
    }
}
