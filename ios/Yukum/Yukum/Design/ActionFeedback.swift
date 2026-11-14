//
//  ActionFeedback.swift
//  Yukum
//
//  İşlem sonrası kısa animasyonlar (15 Kasım) — her seferinde AYNI oynar, hepsi 2B (3B yok):
//    Yük Veren olumlu  → KOLİ KAPANIR + BANTLANIR (ilan ver, kabul, puan, işi bitir)        .seal
//    Yük Veren olumsuz → BANT KESİLİR, KOLİ AÇILIR, "İPTAL" DAMGASI (ret, ilan kaldır, sil) .unseal
//    Taşımacı olumlu   → LASTİK İZİ ekranı geçer (teklif, favori ekle, aşama, tutar)          .track
//    Taşımacı olumsuz  → KAMYONDAN KOLİ BOŞALTILIR (geri çek, favoriden çıkar, sil)          .unload
//  Bir kez oynar (~1,5–2 sn), kaybolur, sonra istenen iş (ör. ekranı kapat) yapılır.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi (yalnız 2B; 3B yok → her ekranda ucuz)

// ┌─ BAĞLANTI HARİTASI: ActionFeedback.swift ─────────────────────────────────────────
// │ GELEN     : Views/CreateListingView (ilan yayınla/güncelle → .seal) | Views/ListingDetailView (teklif ver, favori → .track)
// │             Views/FavoritesView (favoriden çıkar → .track)
// │ GİDEN     : Design/DesignPalette.swift (koli, bant, yazı renkleri)
// │ TEKNİK    : yalnız SwiftUI: şekil + rotation3DEffect (kapak katlanması) + maske (bant çekilmesi) + trim (iz çizilmesi)
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// KULLANIM (ekranda 3 satır):
//   @State private var feedback: ActionFeedback?                                   ← ekranın hafızası
//   .actionFeedback($feedback)                                                      ← ekranın en dışına (body'nin sonuna)
//   feedback = ActionFeedback(.seal, "İlan yayında") { dismiss() }                  ← işlem BAŞARILI olunca
// ZİNCİR: feedback dolar → overlay animasyonu çizer → animasyon biter → feedback = nil (overlay kalkar) → then() çalışır
// NEDEN "then" animasyondan SONRA: ekran hemen kapanırsa animasyon görünmeden yok olurdu.
// NEDEN tek dosya + tek modifier: her ekran aynı 3 satırla bağlansın; animasyon değişecekse yalnız burası değişir.

// BU TÜR: oynatılacak animasyonun tarifi | Identifiable [SWIFT]: her yeni geri bildirim yeni kimlik alır → arka arkaya iki işlemde animasyon baştan oynar
// ⮕ KULLANIM [ActionFeedback]: kullanır: CreateListingView, ListingDetailView, FavoritesView
struct ActionFeedback: Identifiable {
    // OLUMLU: seal = koli bantlama (Yük Veren) | track = lastik izi (Taşımacı)
    // OLUMSUZ (15 Kasım, kullanıcı: "iptallerde paketlenme olmasın, duruma uygun"): unseal = bant kesilir, koli açılır, İPTAL damgası (Yük Veren)
    //   | unload = kamyondan koli boşaltılır (Taşımacı: teklifi geri çekme, favoriden çıkarma, silme)
    enum Kind { case seal, track, unseal, unload }
    let id = UUID()            // [SWIFT] UUID: benzersiz kimlik
    let kind: Kind
    let message: String        // animasyonun altındaki kısa yazı ("İlan yayında")
    var then: (() -> Void)?    // animasyon bitince yapılacak iş (ör. dismiss) | nil olabilir

    init(_ kind: Kind, _ message: String, then: (() -> Void)? = nil) {
        self.kind = kind; self.message = message; self.then = then
    }
}

extension View {
    // BU FONKSİYON: ekrana geri bildirim katmanını ekler. item doluyken animasyon üstte oynar, bitince item'ı boşaltır ve then'i çağırır.
    // ⮕ KULLANIM [actionFeedback]: kullanır: CreateListingView, ListingDetailView, FavoritesView (body sonunda)
    func actionFeedback(_ item: Binding<ActionFeedback?>) -> some View { // Binding [SWIFT]: değer ekranın @State'inde; burada okunur ve boşaltılır
        overlay {
            if let feedback = item.wrappedValue {
                ActionFeedbackOverlay(feedback: feedback) {
                    item.wrappedValue = nil
                    feedback.then?()
                }
                .id(feedback.id) // [SWIFT] yeni kimlik → görünüm baştan kurulur, animasyon baştan oynar
            }
        }
    }
}

// BU GÖRÜNÜM: türüne göre koliyi ya da lastik izini çizer; "Hareketi azalt" açıksa animasyon yerine yalnız yazıyı kısa süre gösterir.
// ⮕ KULLANIM [ActionFeedbackOverlay]: kullanır: View.actionFeedback
private struct ActionFeedbackOverlay: View {
    let feedback: ActionFeedback
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion // [SWIFT] iOS Ayarlar › Erişilebilirlik › Hareketi Azalt

    var body: some View {
        Group {
            switch feedback.kind {
            case .seal: BoxSealAnimation(message: feedback.message, quick: reduceMotion, onFinish: onFinish)
            case .track: TireTrackAnimation(message: feedback.message, quick: reduceMotion, onFinish: onFinish)
            case .unseal: BoxUnsealAnimation(message: feedback.message, quick: reduceMotion, onFinish: onFinish)
            case .unload: UnloadAnimation(message: feedback.message, quick: reduceMotion, onFinish: onFinish)
            }
        }
        .ignoresSafeArea()
    }
}

// ─── YÜK VEREN: KOLİ KAPANIR + BANTLANIR ─────────────────────────────────────────
// SAHNE (önden görünen açık koli): gövde + iç karanlık + iki üst kapak (dışa açık) + etiket.
// ADIMLAR (her biri withAnimation ile, araları Task.sleep):
//   1) kapaklar dikleşir (0,3 sn)        → rotationEffect: dışa ±38° → 0°
//   2) kapaklar içe katlanır (0,32 sn)  → rotation3DEffect: X ekseninde 0° → 78° (üstten bakınca yatık kapak = ince yamuk)
//   3) bant çekilir (0,4 sn)            → üstten aşağı, maskenin yüksekliği 0 → tam | telefon hafifçe titrer
//   4) onay rozeti + yazı belirir, kısa bekler, hepsi solar → onFinish
// ⮕ KULLANIM [BoxSealAnimation]: kullanır: ActionFeedbackOverlay
private struct BoxSealAnimation: View {
    let message: String
    let quick: Bool
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var upright = false   // 1) kapaklar dik mi
    @State private var folded = false    // 2) kapaklar katlandı mı
    @State private var tape: CGFloat = 0 // 3) bandın ne kadarı çekildi (0…1)
    @State private var done = false      // 4) rozet + yazı görünsün mü
    @State private var visible = true    // en sonda solma

    private let w: CGFloat = 210, h: CGFloat = 140 // koli gövdesi ölçüsü (nokta)

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        let kraft = Color(uiColor: palette.boxColors[0]), dark = Color(uiColor: palette.boxColors[1]) // gerçek koli tonları (3B kolilerle aynı)

        ZStack {
            Color.black.opacity(0.35) // arkayı karart: dikkat koliye gelsin, alttaki düğmeye ikinci kez basılmasın

            VStack(spacing: 22) {
                ZStack(alignment: .top) {
                    // İÇ KARANLIK: kapaklar açıkken kolinin içi görünür
                    Rectangle().fill(Color.black.opacity(0.45)).frame(width: w - 8, height: 12).offset(y: -10) // kapaklar katlanınca üstü kapanır

                    // KAPAKLAR: menteşe gövdenin üst kenarı | sol kapak sol yarı, sağ kapak sağ yarı
                    HStack(spacing: 0) {
                        flap(kraft, dark, leading: true)
                        flap(kraft, dark, leading: false)
                    }
                    .frame(width: w, height: h * 0.42)
                    .offset(y: -h * 0.42) // gövdenin hemen üstünde

                    // GÖVDE: önden koli yüzü + üstte koyu kenar + sağ altta kargo etiketi + ↑↑ işareti
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [kraft, dark], startPoint: .top, endPoint: .bottom))
                        .frame(width: w, height: h)
                        .overlay(alignment: .top) { Rectangle().fill(dark.opacity(0.6)).frame(height: 3) }
                        .overlay(alignment: .bottomTrailing) { label.padding(10) }
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 1) { Image(systemName: "arrow.up"); Image(systemName: "arrow.up") } // "bu taraf yukarı" işareti
                                .font(.caption.bold()).foregroundStyle(dark.opacity(0.8)).padding(10)
                        }

                    // BANT: gövdenin ortasından, üst kenardan aşağı çekilir (gerçek kolide kapak birleşim yerinden ön yüze iner)
                    tapeStrip(palette)
                        .frame(width: 34, height: h + 10)
                        .mask(alignment: .top) { Rectangle().frame(height: (h + 10) * tape) } // maske: bant uzuyormuş gibi (yazı ezilmez)
                        .offset(y: -8)
                }
                .frame(width: w, height: h)
                .padding(.top, h * 0.42)
                // GÖLGE (15 Kasım performans): .shadow kapaklar dönerken her karede yeniden bulanıklaştırılıyordu → sabit, yumuşak bir zemin elipsi
                .background(alignment: .bottom) { Ellipse().fill(RadialGradient(colors: [.black.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 130)).frame(width: 260, height: 40).offset(y: 18) }
                .overlay(alignment: .topTrailing) { // 4) ONAY ROZETİ: koli üstüne basılan damga gibi
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(palette.accent)
                        .background(Circle().fill(palette.buttonText).padding(6))
                        .scaleEffect(done ? 1 : 0.2).opacity(done ? 1 : 0)
                        .offset(x: 18, y: h * 0.42 - 18)
                }

                Text(message)
                    .font(.headline).foregroundStyle(palette.buttonText)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(palette.accent, in: .capsule)
                    .opacity(done ? 1 : 0).offset(y: done ? 0 : 10)
            }
        }
        .opacity(visible ? 1 : 0)
        .sensoryFeedback(.impact(weight: .medium), trigger: tape == 1) // [SWIFT] bant tam çekilince telefon "tık" der
        .task { await run() } // .task [SWIFT]: görünür olunca çalışır; görünüm kalkarsa kendiliğinden iptal olur
    }

    // Bir kapak: dışa açık başlar → dikleşir → içe katlanır. anchor .bottom* = menteşe gövdenin üst kenarında
    private func flap(_ kraft: Color, _ dark: Color, leading: Bool) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [kraft.opacity(0.95), dark], startPoint: .top, endPoint: .bottom))
            .overlay(Rectangle().stroke(dark.opacity(0.5), lineWidth: 1))
            .rotationEffect(.degrees(upright ? 0 : (leading ? -38 : 38)), anchor: leading ? .bottomLeading : .bottomTrailing) // 1) dışa açık → dik
            .rotation3DEffect(.degrees(folded ? 78 : 0), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.55)         // 2) dik → yatık
    }

    // Kargo etiketi: beyaz kart, üstte iki gri satır, altta barkod çizgileri (CardboardArt'taki etiketin 2B özeti)
    private var label: some View {
        VStack(alignment: .leading, spacing: 3) {
            Capsule().fill(.gray.opacity(0.5)).frame(width: 30, height: 3)
            Capsule().fill(.gray.opacity(0.35)).frame(width: 22, height: 3)
            HStack(spacing: 1.5) { ForEach(0..<9, id: \.self) { i in Rectangle().fill(.black.opacity(0.7)).frame(width: i % 3 == 0 ? 2 : 1, height: 9) } }
        }
        .padding(5).background(.white.opacity(0.92), in: .rect(cornerRadius: 2))
    }

    // Bant: parlak bej şerit + tekrar eden "YÜKÜM" (giriş ekranındaki ScreenTape ile aynı dil, dikey)
    private func tapeStrip(_ palette: Palette) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [palette.screenTape.opacity(0.95), palette.screenTape.opacity(0.75), palette.screenTape.opacity(0.95)],
                                 startPoint: .leading, endPoint: .trailing))
            .overlay {
                VStack(spacing: 14) { ForEach(0..<4, id: \.self) { _ in Text("YÜKÜM").font(.system(size: 7, weight: .black)).rotationEffect(.degrees(90)).fixedSize() } }
                    .foregroundStyle(.black.opacity(0.35))
            }
            .clipped()
    }

    private func run() async {
        if quick { // Hareketi azalt: yalnız son hal + yazı
            upright = true; folded = true; tape = 1; done = true
            try? await Task.sleep(for: .seconds(0.9)); onFinish(); return
        }
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.easeOut(duration: 0.3)) { upright = true }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeIn(duration: 0.32)) { folded = true }
        try? await Task.sleep(for: .seconds(0.34))
        withAnimation(.easeInOut(duration: 0.4)) { tape = 1 }
        try? await Task.sleep(for: .seconds(0.42))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { done = true } // [SWIFT] yay: rozet "pat" diye basılır
        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(.easeOut(duration: 0.25)) { visible = false }
        try? await Task.sleep(for: .seconds(0.25))
        onFinish()
    }
}

// ─── YÜK VEREN İPTAL: BANT KESİLİR, KOLİ AÇILIR, "İPTAL" DAMGASI ─────────────────────
// Bantlamanın TERSİ (iptal edilen iş "paketten çıkarılır"): kapalı, bantlı koli → bant ortadan kesilir, iki yarısı yana düşer
//   → kapaklar dışa açılır → kırmızı "İPTAL" damgası basılır (telefon uyarı titreşimi) → yazı → solar.
// Sahne BoxSealAnimation ile aynı ölçü ve renklerde; tek fark yön ve damga. Her seferinde birebir aynı (rastgelelik yok).
// ⮕ KULLANIM [BoxUnsealAnimation]: kullanır: ActionFeedbackOverlay (.unseal)
private struct BoxUnsealAnimation: View {
    let message: String
    let quick: Bool
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var cut = false      // 1) bant kesildi (iki yarı yana açılır)
    @State private var open = false     // 2) kapaklar açıldı
    @State private var stamped = false  // 3) İPTAL damgası
    @State private var visible = true

    private let w: CGFloat = 210, h: CGFloat = 140

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        let kraft = Color(uiColor: palette.boxColors[0]), dark = Color(uiColor: palette.boxColors[1])

        ZStack {
            Color.black.opacity(0.35)
            VStack(spacing: 22) {
                ZStack(alignment: .top) {
                    Rectangle().fill(Color.black.opacity(0.45)).frame(width: w - 8, height: 12).offset(y: -10) // iç karanlık (kapaklar açılınca görünür)
                    HStack(spacing: 0) { // kapaklar: önce yatık (kapalı), sonra dikleşip dışa açılır
                        flap(kraft, dark, leading: true)
                        flap(kraft, dark, leading: false)
                    }
                    .frame(width: w, height: h * 0.42)
                    .offset(y: -h * 0.42)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [kraft, dark], startPoint: .top, endPoint: .bottom))
                        .frame(width: w, height: h)
                        .overlay(alignment: .top) { Rectangle().fill(dark.opacity(0.6)).frame(height: 3) }

                    // BANT: iki yarı | kesilince sol yarı sola, sağ yarı sağa kayar, döner ve solar (kesilip düşmüş gibi)
                    HStack(spacing: 0) {
                        tapeHalf(palette).offset(x: cut ? -26 : 0, y: cut ? 30 : 0).rotationEffect(.degrees(cut ? -14 : 0))
                        tapeHalf(palette).offset(x: cut ? 26 : 0, y: cut ? 30 : 0).rotationEffect(.degrees(cut ? 14 : 0))
                    }
                    .opacity(cut ? 0 : 1)
                    .frame(width: 34, height: h + 10).offset(y: -8)
                }
                .frame(width: w, height: h)
                .padding(.top, h * 0.42)
                // GÖLGE (15 Kasım performans): .shadow kapaklar dönerken her karede yeniden bulanıklaştırılıyordu → sabit, yumuşak bir zemin elipsi
                .background(alignment: .bottom) { Ellipse().fill(RadialGradient(colors: [.black.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 130)).frame(width: 260, height: 40).offset(y: 18) }
                .overlay { // 3) İPTAL DAMGASI: kolinin önüne eğik basılır (büyükten küçüğe "pat")
                    Text("İPTAL")
                        .font(.system(size: 34, weight: .black, design: .rounded)).tracking(3)
                        .foregroundStyle(palette.danger)
                        .padding(.horizontal, 14).padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.danger, lineWidth: 4))
                        .rotationEffect(.degrees(-12))
                        .scaleEffect(stamped ? 1 : 1.8).opacity(stamped ? 0.92 : 0)
                        .offset(y: h * 0.21)
                }

                Text(message)
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(palette.danger, in: .capsule)
                    .opacity(stamped ? 1 : 0).offset(y: stamped ? 0 : 10)
            }
        }
        .opacity(visible ? 1 : 0)
        .sensoryFeedback(.warning, trigger: stamped) // [SWIFT] uyarı titreşimi: olumsuz işlem hissi
        .task { await run() }
    }

    // Kapak: kapalıyken yatık (78°), açılınca dik (0°) ve dışa ±38°
    private func flap(_ kraft: Color, _ dark: Color, leading: Bool) -> some View {
        Rectangle()
            .fill(LinearGradient(colors: [kraft.opacity(0.95), dark], startPoint: .top, endPoint: .bottom))
            .overlay(Rectangle().stroke(dark.opacity(0.5), lineWidth: 1))
            .rotationEffect(.degrees(open ? (leading ? -38 : 38) : 0), anchor: leading ? .bottomLeading : .bottomTrailing)
            .rotation3DEffect(.degrees(open ? 0 : 78), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.55)
    }

    private func tapeHalf(_ palette: Palette) -> some View {
        Rectangle().fill(palette.screenTape.opacity(0.9))
            .overlay(alignment: .center) { Rectangle().fill(.black.opacity(0.08)).frame(width: 1) }
    }

    private func run() async {
        if quick { cut = true; open = true; stamped = true; try? await Task.sleep(for: .seconds(0.9)); onFinish(); return }
        try? await Task.sleep(for: .seconds(0.2))
        withAnimation(.easeIn(duration: 0.35)) { cut = true }       // bant kesilir, düşer
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { open = true } // kapaklar "pat" diye açılır
        try? await Task.sleep(for: .seconds(0.4))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { stamped = true } // damga
        try? await Task.sleep(for: .seconds(0.9))
        withAnimation(.easeOut(duration: 0.25)) { visible = false }
        try? await Task.sleep(for: .seconds(0.25))
        onFinish()
    }
}

// ─── TAŞIMACI İPTAL: KAMYONDAN KOLİ BOŞALTILIR ────────────────────────────────────────
// Lastik izinin TERSİ (yük araçtan iner): ekranın ortasında kamyon, arka kapısının önünde koli → koli kayıp düşer, yere oturur
//   → kamyon yükünü bırakmış, hafifçe öne çıkar → kiremit renkli yazı → solar. Arka plan hafif kararır.
// Kamyon SF Symbols "truck.box.fill" (önü sağda) → koli kamyonun SOL tarafından (arkası) iner.
// ⮕ KULLANIM [UnloadAnimation]: kullanır: ActionFeedbackOverlay (.unload)
private struct UnloadAnimation: View {
    let message: String
    let quick: Bool
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var slid = false     // 1) koli kasadan dışarı kaydı
    @State private var dropped = false  // 2) koli yere düştü
    @State private var leave = false    // 3) kamyon öne çıktı
    @State private var visible = true

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        let kraft = Color(uiColor: palette.boxColors[0]), dark = Color(uiColor: palette.boxColors[1])

        ZStack {
            Color.black.opacity(0.25)
            VStack(spacing: 26) {
                ZStack(alignment: .bottom) {
                    Capsule().fill(palette.title.opacity(0.25)).frame(width: 260, height: 4) // yer çizgisi
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 92)).foregroundStyle(palette.title.opacity(0.9))
                        .offset(x: leave ? 70 : 0, y: -4)
                        .opacity(leave ? 0 : 1)
                    // KOLİ: kamyonun arkasından (sol) kayar → düşerken döner → yere oturur
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [kraft, dark], startPoint: .top, endPoint: .bottom))
                        .overlay(Rectangle().fill(palette.screenTape.opacity(0.9)).frame(width: 8)) // bant
                        .frame(width: 42, height: 34)
                        .rotationEffect(.degrees(dropped ? -8 : (slid ? -28 : 0)))
                        .offset(x: slid ? -78 : -40, y: dropped ? -4 : -46)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
                }
                .frame(width: 260, height: 110)

                Label(message, systemImage: "shippingbox.and.arrow.backward.fill")
                    .font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(palette.danger, in: .capsule)
                    .opacity(dropped ? 1 : 0).scaleEffect(dropped ? 1 : 0.85)
            }
        }
        .opacity(visible ? 1 : 0)
        .sensoryFeedback(.impact(weight: .heavy), trigger: dropped) // koli yere "güm" diye iner
        .task { await run() }
    }

    private func run() async {
        if quick { slid = true; dropped = true; try? await Task.sleep(for: .seconds(0.9)); onFinish(); return }
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.easeOut(duration: 0.3)) { slid = true }                       // kasadan dışarı kayar
        try? await Task.sleep(for: .seconds(0.28))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) { dropped = true } // düşer, hafif sekip oturur
        try? await Task.sleep(for: .seconds(0.45))
        withAnimation(.easeIn(duration: 0.45)) { leave = true }                      // kamyon yükünü bırakıp gider
        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(.easeOut(duration: 0.25)) { visible = false }
        try? await Task.sleep(for: .seconds(0.25))
        onFinish()
    }
}

// ─── TAŞIMACI: LASTİK İZİ ─────────────────────────────────────────────────────────
// SAHNE: ekranın sol altından sağ üstüne kıvrılarak giden iki paralel tekerlek izi (çift lastik) + yazı rozeti.
// NASIL iz "çizilir": her iz aynı eğri (TrackCurve); .trim(from: 0, to: progress) [SWIFT] eğrinin yalnız başını çizer, progress 0 → 1 olunca iz uzar.
//   Diş deseni: kalın, KESİK çizgi (dash) → enine diş blokları; altında soluk, kalın düz çizgi → lastiğin bıraktığı silik iz.
// ADIMLAR: iz uzar (0,6 sn) → yazı belirir → bekler → solar → onFinish. Arka plan KARARMAZ (ekran üstünden bir araç geçmiş gibi).
// ⮕ KULLANIM [TireTrackAnimation]: kullanır: ActionFeedbackOverlay
private struct TireTrackAnimation: View {
    let message: String
    let quick: Bool
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var progress: CGFloat = 0
    @State private var done = false
    @State private var visible = true

    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        let rubber = palette.isDark ? Color.white : Color(red: 0.16, green: 0.12, blue: 0.09) // gece açık iz (koyu zeminde görünsün), gündüz koyu lastik

        ZStack {
            Color.black.opacity(0.001) // [SWIFT] görünmez ama dokunuş alır → animasyon sırasında düğmeye ikinci kez basılmaz
            ForEach([-42.0, 42.0], id: \.self) { gap in // iki tekerlek: eğrinin iki yanında, aks genişliği kadar aralık
                ZStack {
                    TrackCurve(offset: gap).trim(from: 0, to: progress)
                        .stroke(rubber.opacity(0.12), style: StrokeStyle(lineWidth: 30, lineCap: .butt))                // lastiğin bıraktığı silik iz
                    // DİŞ DESENİ: lastiğin iki yarısında ŞAŞIRTMALI bloklar (dashPhase ile yarım adım kaydırılır)
                    //   (15 Kasım ilk denemede tek sıra enine çizgi vardı → tren rayı gibi görünüyordu)
                    TrackCurve(offset: gap - 7).trim(from: 0, to: progress)
                        .stroke(rubber.opacity(0.38), style: StrokeStyle(lineWidth: 11, lineCap: .butt, dash: [8, 6]))
                    TrackCurve(offset: gap + 7).trim(from: 0, to: progress)
                        .stroke(rubber.opacity(0.38), style: StrokeStyle(lineWidth: 11, lineCap: .butt, dash: [8, 6], dashPhase: 7))
                }
            }

            Label(message, systemImage: "truck.box.fill")
                .font(.headline).foregroundStyle(palette.buttonText)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(palette.accent, in: .capsule)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2) // küçük yarıçap: ucuz
                .scaleEffect(done ? 1 : 0.85).opacity(done ? 1 : 0)
        }
        .opacity(visible ? 1 : 0)
        .sensoryFeedback(.impact(weight: .light), trigger: done)
        .task { await run() }
    }

    private func run() async {
        if quick {
            progress = 1; done = true
            try? await Task.sleep(for: .seconds(0.9)); onFinish(); return
        }
        withAnimation(.easeOut(duration: 0.6)) { progress = 1 } // hızla girip yavaşlar: araç geçti
        try? await Task.sleep(for: .seconds(0.4))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { done = true }
        try? await Task.sleep(for: .seconds(0.95))
        withAnimation(.easeOut(duration: 0.3)) { visible = false }
        try? await Task.sleep(for: .seconds(0.3))
        onFinish()
    }
}

// Lastik izinin yolu: sol alttan girip ortada hafif S çizerek sağ üstten çıkan eğri.
// offset: eğriye DİK yönde kaydırma (iki tekerleğin arası) | yaklaşık: uç noktaları yatayda kaydırmak bu eğimde yeterince paralel görünür
// ⮕ KULLANIM [TrackCurve]: kullanır: TireTrackAnimation
private struct TrackCurve: Shape { // Shape [SWIFT]: kodla çizilen şekil; .trim ve .stroke bunun üstünde çalışır
    var offset: CGFloat
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, d = offset
        var path = Path()
        path.move(to: CGPoint(x: -40 + d, y: h * 0.86 + d))
        path.addCurve(to: CGPoint(x: w + 40 + d, y: h * 0.18 + d),           // addCurve [SWIFT]: iki kontrol noktalı yumuşak eğri
                      control1: CGPoint(x: w * 0.45 + d, y: h * 0.95 + d),
                      control2: CGPoint(x: w * 0.40 + d, y: h * 0.10 + d))
        return path
    }
}

// ─── İKİNCİL EKRANLARIN ZEMİNİ ────────────────────────────────────────────────────
// BU GÖRÜNÜM: giriş/ilan ver ekranlarıyla aynı renk geçişi + iki bulanık ışık halesi. Animasyonsuz (ikincil ekranlarda sahne yok).
// NEDEN burada: tema parçası; ekranlar .background { ScreenBackground() } ile kullanır, renk değişecekse yalnız palet değişir.
// ⮕ KULLANIM [ScreenBackground]: kullanır: ListingDetailView, FavoritesView
struct ScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        let palette = Palette(isDark: colorScheme == .dark)
        ZStack {
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)
            SoftGlow(color: palette.glowA, width: 380, height: 320).offset(x: -120, y: -220)
            SoftGlow(color: palette.glowB, width: 360, height: 300).offset(x: 130, y: 220)
        }
        .ignoresSafeArea()
    }
}

// BU GÖRÜNÜM: yumuşak kenarlı ışık halesi (arka plandaki amber bulutlar).
// PERFORMANS (15 Kasım): önceden Ellipse().blur(radius: 95) idi. .blur [SWIFT] görüntüyü ekran dışında ayrı bir tuvale çizip
//   her pikseli komşularıyla karıştırır; 95 noktalık bulanıklık çok pahalıdır ve üstünde bir şey kaydıkça tekrar hesaplanabilir.
//   RadialGradient [SWIFT]: merkezden kenara solan renk → gözle aynı yumuşak hale, ama tek geçişte, bulanıklık hesabı YOK.
//   Ölçü 1,9 kat: bulanıklık haleyi dışa doğru yayıyordu; aynı kaplama alanını vermek için gradyan daha geniş çizilir.
// ⮕ KULLANIM [SoftGlow]: kullanır: ScreenBackground, SceneBackground, HomeView › shipperBackground, CreateListingView, RoleSelectionView
struct SoftGlow: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: max(width, height) * 0.95))
            .frame(width: width * 1.9, height: height * 1.9)
            .frame(width: width, height: height) // YERLEŞİMDE eski ölçü: büyük hale taşar ama ekranı genişletmez (15 Kasım: giriş formu sola kayıyordu)
    }
}
