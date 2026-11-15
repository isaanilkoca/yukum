//
//  TermsView.swift
//  Yukum
//
//  Kullanım Koşulları (15 Kasım, Apple kuralı 1.2: kullanıcılar arası içerikte "kötüye kullanıma sıfır tolerans" koşulu kabul ettirilmeli).
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: TermsView ────────────────────────────────────────────────
// │ AÇAN    : Design/FormStyle › FormConsent(document: .terms) "Kullanım Koşulları'nı oku" (kayıt) · Views/ProfileView "Kullanım Koşulları"
// │ ONAY    : RegisterViewModel / CarrierRegisterViewModel.termsAccepted → istek termsAccepted → backend RegisterValidators.TermsAccepted (zorunlu)
// │           kabul anı sunucuda saklanır: Users.TermsAcceptedAt (kanıt)
// │ BAĞLI   : şikâyet/engelle akışı Views/SafetyViews (metindeki "⋯ menüsü")
// └──────────────────────────────────────────────────────────────────────
// NEDEN KVKK'dan ayrı sayfa ve ayrı kutu: KVKK aydınlatma/açık rıza başka bir sözleşmeyle tek onayda birleştirilmez.

// ⮕ KULLANIM [TermsView]: FormConsent, ProfileView (.sheet)
struct TermsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    block("Yüküm nedir?",
                          "Yüküm, yük vermek isteyenlerle taşımacıları buluşturan bir platformdur. Taşıma anlaşması Yük Veren ile Taşımacı arasında yapılır; Yüküm bu anlaşmanın tarafı değildir. Ödeme uygulama dışında, taraflar arasında yapılır.")
                    block("Hesabın",
                          "Kayıtta doğru bilgi vermelisin. Şifreni kimseyle paylaşma; hesabından yapılan işlemlerden sen sorumlusun. Her rolde (Yük Veren / Taşımacı) yalnız bir hesap açabilirsin.")
                    block("Kötüye kullanıma sıfır tolerans",
                          "Şunlar kesinlikle yasaktır: dolandırıcılık ya da ön ödeme aldatmacası, sahte ilan veya teklif, hakaret, taciz, tehdit, nefret söylemi, müstehcen içerik, spam ve reklam, yasa dışı ya da yasaklı yük taşıma talebi. Bu kurallara uymayan içerik kaldırılır, hesap uyarı yapılmadan kapatılabilir.")
                    block("Şikâyet et ve engelle",
                          "Sohbet, ilan ve profil ekranlarındaki ⋯ menüsünden bir kullanıcıyı şikâyet edebilir ya da engelleyebilirsin. Engellediğin kişiyle mesajlaşamaz, teklif alışverişi yapamazsın. Şikâyetler en geç 24 saat içinde incelenir; kurala aykırı içerik kaldırılır ve gerekirse hesap kapatılır.")
                    block("Sorumluluk",
                          "Yükün tanımı, ağırlığı ve teslim koşullarının doğruluğundan Yük Veren; aracın, belgelerin ve taşımanın güvenliğinden Taşımacı sorumludur. Yüküm, taraflar arasındaki anlaşmazlıklarda taraf değildir ama şikâyetleri inceler.")
                    block("Değişiklikler",
                          "Bu koşullar güncellenebilir. Önemli bir değişiklik olursa uygulamada bildirilir; uygulamayı kullanmaya devam etmen güncel koşulları kabul ettiğin anlamına gelir.")
                }
                .padding()
            }
            .background { ScreenBackground() } // ⮕ Design/ActionFeedback.swift
            .navigationTitle("Kullanım Koşulları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() } } }
        }
    }

    // block: "başlık + açıklama" kalıbı (PrivacyView ile aynı görünüm)
    private func block(_ title: String, _ text: String) -> some View {
        let palette = Palette(isDark: colorScheme == .dark)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(palette.title)
            Text(text).font(.subheadline).foregroundStyle(palette.label.opacity(0.8))
        }
        .themedCard() // ⮕ Design/FormStyle.swift
    }
}

#Preview { TermsView() }
