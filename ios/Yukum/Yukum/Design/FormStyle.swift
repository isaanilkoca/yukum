//
//  FormStyle.swift
//  Yukum
//
//  Form görünümü: opak kart (FormCard) + etiketli giriş kutusu (LabeledInput). Hareketli arka planın üstünde formu NET ayırır.
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: FormStyle.swift ─────────────────────────────────────────
// │ GELEN     : Views/LoginView.swift → FormCard { LabeledInput(...) { TextField(...) } ... } | Views/RoleSelectionView (tek kayıt ekranı), RegisterView, CarrierRegisterView
// │ GİDEN     : Design/DesignPalette.swift (kart ve kutu renkleri)
// │ TEKNİK    : yalnız SwiftUI. İçerik dışarıdan verilir (@ViewBuilder) → alanın NE olduğu (TextField, Picker) ekranda kalır, NASIL göründüğü burada.
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────

// NEDEN kart: arkada koliler ve bantlar var. Tek tek buzlu cam kutular onların içinde kayboluyordu;
//   kullanıcı "nereye yazacağım" diye aramamalı. Kart arka planı bulanıklaştırıp koyulaştırır → form tek bakışta okunur.
//   Kart bilerek ŞEFFAF: arkadaki animasyon görünmeye devam eder; kart yalnız formun sınırını belli eder.
// NEDEN etiket alanın ÜSTÜNDE: kutunun içindeki silik ipucu (placeholder) yazmaya başlayınca kaybolur; üstteki etiket hep görünür.

// BU GÖRÜNÜM: formu saran opak, köşeleri yuvarlak, gölgeli kart.
// ⮕ KULLANIM [FormCard]: kullanır: LoginView › body
struct FormCard<Content: View>: View { // <Content: View> [SWIFT]: içine herhangi bir görünüm alabilen genel yapı
    @Environment(\.colorScheme) private var colorScheme // [SWIFT] telefon açık modda mı koyu modda mı
    @ViewBuilder var content: Content // @ViewBuilder [SWIFT]: süslü parantez içinde alt alta görünüm yazmayı sağlar

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 16) { content } // alignment: .leading → etiketler sola yaslı
            .padding(20)
            // Zemin: yalnız hafif renkli, ŞEFFAF bir katman. Bulanıklaştırma (material) YOK → arkadaki koliler ve bantlar net görünür.
            // Okunaklılığı kart değil, içindeki giriş kutuları sağlar (onlar daha opak: LabeledInput).
            .background(palette.cardSurface.opacity(palette.cardOpacity), in: .rect(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(palette.cardBorder))    // çok ince kenar çizgisi

    }
}

// BU GÖRÜNÜM: üstte etiket, altta solunda simge olan giriş kutusu. Kutunun içine ne konacağı (TextField, SecureField) dışarıdan verilir.
// ⮕ KULLANIM [LabeledInput]: kullanır: LoginView › body
struct LabeledInput<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String        // kutunun üstündeki yazı (örn. "Şifre")
    let systemImage: String  // SF Symbols simge adı (örn. "lock.fill")
    @ViewBuilder var content: Content

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.label)
                .shadow(color: palette.labelShadow, radius: 3) // şeffaf kartta, kolinin üstüne denk gelse de okunsun
            HStack(spacing: 12) { // HStack [SWIFT]: yan yana dizer → simge + alan
                Image(systemName: systemImage) // Image(systemName:) [SWIFT]: Apple'ın hazır simge seti (SF Symbols)
                    .foregroundStyle(palette.accent)
                    .frame(width: 22)
                content
                    .foregroundStyle(palette.title)
                    .tint(palette.accent) // imleç rengi
            }
            .padding(.horizontal, 14)
            .frame(height: 52) // sabit yükseklik: parmakla rahat basılır (Apple önerisi en az 44)
            .background(palette.fieldSurface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.fieldBorder))
        }
    }
}

// ─── KAYIT FORMU PARÇALARI (14 Kasım: tek kayıt ekranı) ─────────────────────────
// NEDEN burada: Yük Veren ve Taşımacı formları aynı düğmeyi, aynı KVKK satırını, aynı mesaj kutusunu kullanır → kod tekrarı olmasın, görünüm tek yerden değişsin.

// BU GÖRÜNÜM: turuncu, tam genişlik ana düğmenin GÖRÜNÜMÜ (giriş ekranındaki "Giriş yap" ile aynı). Davranışı çağıran Button verir.
// ⮕ KULLANIM [AccentButtonLabel]: kullanır: RegisterView, CarrierRegisterView (Button label'ı)
struct AccentButtonLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        Text(title)
            .font(.headline)
            .foregroundStyle(palette.buttonText)
            .frame(maxWidth: .infinity).frame(height: 54) // parmakla rahat basılır
            .background(palette.accent, in: .rect(cornerRadius: 14)) // koli bandı turuncusu
    }
}

// BU GÖRÜNÜM: KVKK onayı. Solda onay kutusu (basınca işaretlenir), yanında metin; altında "KVKK metnini oku" bağlantısı (alttan sayfa açar).
// NEDEN Toggle değil kutu: anahtar (Toggle) bir ayar gibi duruyor; sözleşme onayı için alışılmış görünüm işaret kutusudur.
// ⮕ KULLANIM [FormConsent]: kullanır: RegisterView, CarrierRegisterView
struct FormConsent: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isOn: Bool // @Binding [SWIFT]: değer çağıranın (ViewModel.kvkkAccepted); burada değişince orada da değişir
    @State private var showPrivacy = false

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 6) {
            Button { isOn.toggle() } label: { // .toggle() [SWIFT]: true ↔ false
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(isOn ? palette.accent : palette.label.opacity(0.6))
                    Text("KVKK aydınlatma metnini okudum, onaylıyorum.")
                        .font(.footnote)
                        .foregroundStyle(palette.label)
                        .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain) // [SWIFT] düğme yazıyı maviye boyamasın
            Button("KVKK metnini oku") { showPrivacy = true }
                .font(.footnote.weight(.semibold))
                .tint(palette.accent)
                .padding(.leading, 32) // kutunun hizasından değil, yazının hizasından başlasın
                .sheet(isPresented: $showPrivacy) { PrivacyView() } // ⮕ Views/PrivacyView
        }
        .padding(.top, 2)
    }
}

// BU GÖRÜNÜM: formun altındaki hata (kırmızı, uyarı simgesi) ya da başarı (yeşil, tik simgesi) yazısı.
// Simge + renk: durum yalnız renge bağlı kalmasın (renk ayırt edemeyen kullanıcı da anlasın).
// ⮕ KULLANIM [FormMessage]: kullanır: RegisterView, CarrierRegisterView
struct FormMessage: View {
    let text: String
    let isError: Bool

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill") // Label [SWIFT]: simge + yazı
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isError ? Color.red : Color.green)
    }
}
