//
//  YukumLogo.swift
//  Yukum
//
//  Yüküm logosu: konum işaretinin içinde bantlı koli ("yükün nerede, yolda"). Uygulama simgesiyle AYNI çizim (15 Kasım, B fikri).
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: YukumLogo.swift ─────────────────────────────────────────
// │ GELEN     : Views/LoginView (büyük, bir kez animasyonlu) | Views/HomeView (üst çubukta BrandTitle)
// │ GİDEN     : Design/DesignPalette.swift (turuncu işaret, koli tonları)
// │ AYNI ÇİZİM: Assets › AppIcon (1024 px; işaret orada krem, zemin turuncu) — ölçüler birebir aynı orantıda
// │ REHBER    : Design/00_Rehber_Design.swift
// └──────────────────────────────────────────────────────────────────────
//
// NEDEN KODLA ÇİZİLİYOR (resim değil): her boyutta keskin, gece/gündüz rengine uyar, uygulamaya resim dosyası eklemez.
// ORANLAR (simgeden): işaret 540 × 720 birim; baş dairesinin yarıçapı = genişliğin yarısı, merkezi üstten genişliğin yarısı kadar aşağıda.
//   Uç (sivri kısım) en altta. Koli: genişliğin %56'sı × %46'sı, dairenin merkezinde.
// ANİMASYON (yalnız giriş ekranı, bir kez): işaret yukarıdan inip yerine oturur, koli içinde "pat" diye belirir.
//   Logo alanının DIŞINA taşmaz, hiçbir yazıya ya da alana değmez (animasyon ilkesi, 15 Kasım).

// ⮕ KULLANIM [YukumLogo]: kullanır: LoginView › body, BrandTitle › body
struct YukumLogo: View {
    var size: CGFloat          // logonun YÜKSEKLİĞİ (nokta); genişlik = yükseklik × 0,75
    var animated = false       // true: görününce bir kez iner + koli belirir
    var spinning = false       // true: (indikten sonra) sürekli, yavaşça dikey eksende 360° döner — giriş ekranı canlı dursun (15 Kasım kullanıcı isteği)

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion // [SWIFT] "Hareketi Azalt" açıksa dönme yok
    @State private var landed = false
    @State private var spinStart: Date? // dönüşün başladığı an (nil = dönmüyor)

    // 5 sn'de bir tur | cos ile genişlik çarpanı (çok küçük değerde tamamen kaybolmasın diye en az ±0,04)
    private func spinScale(at date: Date?) -> CGFloat {
        guard let spinStart, let date else { return 1 }
        let turns = date.timeIntervalSince(spinStart) / 5
        // abs: arka yüz de DÜZ görünür (eksi ölçek yazıyı aynalıyordu: "MÜKÜY") → para hep ön yüzüyle döner
        return CGFloat(max(0.04, abs(cos(turns * 2 * .pi))))
    }

    var body: some View {
        if spinStart != nil {
            // TimelineView(.animation) [SWIFT]: ekran yenilendikçe (60/120 Hz) içini yeniden çizer → yalnız bu küçük logo
            TimelineView(.animation) { context in logo(at: context.date) }
        } else {
            logo(at: nil)
        }
    }

    @ViewBuilder // [SWIFT] içinde let + görünüm yazılabilsin (body gibi)
    private func logo(at date: Date?) -> some View {
        let palette = Palette(isDark: colorScheme == .dark)
        let w = size * 0.75
        ZStack(alignment: .top) {
            PinShape().fill(palette.accent)
            box(width: w)
                .padding(.top, w * 0.5 - w * 0.463 / 2 + w * 0.028) // dairenin merkezine (simgedeki küçük aşağı kayma dahil)
                .scaleEffect(landed || !animated ? 1 : 0.3)
                .opacity(landed || !animated ? 1 : 0)
        }
        .frame(width: w, height: size)
        // DÖNÜŞ (15 Kasım, kullanıcı: "daha keskin olsun"): önceden rotation3DEffect (perspektifli 3B) idi → logo her karede resim olarak
        //   yeniden örnekleniyor, kenarları yumuşuyordu. Şimdi madeni para dönüşü YATAY ÖLÇEKLE verilir: genişlik × cos(açı).
        //   |cos| 1 → tam yüz, 0 → kenardan (ince çizgi); arka yarı turda da ön yüz görünür (yazı aynalanmaz). Düz 2B ölçek → hep vektör keskinliğinde.
        .scaleEffect(x: spinScale(at: date), y: 1)
        .offset(y: landed || !animated ? 0 : -size * 0.35) // yalnız kendi boyunun üçte biri kadar yukarıdan: alanından taşmaz
        .opacity(landed || !animated ? 1 : 0)
        .task {
            if animated, !landed {
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { landed = true } // [SWIFT] yay: hafif sekip oturur
                try? await Task.sleep(for: .milliseconds(700))
            }
            // SÜREKLİ DÖNÜŞ: 0 → 360° her 5 sn'de bir, doğrusal (hız sabit), sonsuz | repeatForever [SWIFT]: animasyon hiç bitmez
            // PERFORMANS: tek küçük görünümün dönüşü; ekran kartı her karede yalnız bu küçük alanı yeniden birleştirir (3B motor YOK)
            if spinning, !reduceMotion { spinStart = .now }
        }
        .accessibilityLabel("Yüküm") // [SWIFT] VoiceOver logoyu adıyla okusun
    }

    // Koli: kapak bandı (açık ton) + kapak çizgisi + dikey koli bandı | renkler 3B kolilerle aynı aile
    private func box(width w: CGFloat) -> some View {
        let bw = w * 0.556, bh = w * 0.463
        let kraft = Color(red: 0.84, green: 0.63, blue: 0.38), light = Color(red: 0.91, green: 0.75, blue: 0.52)
        let seam = Color(red: 0.69, green: 0.48, blue: 0.26), tape = Color(red: 0.96, green: 0.87, blue: 0.67)
        // 15 Kasım (kullanıcı: "bantta YÜKÜM yazsın, 3B kutu ile aynı kutu olsun"): kapak bandı + ortadan geçen YÜKÜM bandı
        //   (3B kolide de aynı iki bant var: Design/LoginBoxDrop › brand)
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: bw * 0.09).fill(kraft)
            RoundedRectangle(cornerRadius: bw * 0.09).fill(light).frame(height: bh * 0.30)
            Rectangle().fill(seam).frame(height: max(1, bw * 0.027)).offset(y: bh * 0.30)
            Rectangle().fill(tape).frame(width: bw * 0.2, height: bh * 0.42)             // kapaktan inen bant
            Rectangle().fill(tape).frame(height: bh * 0.30).offset(y: bh * 0.52)          // ortadan geçen marka bandı
                .overlay(alignment: .top) {
                    Text("YÜKÜM").font(.system(size: bh * 0.2, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.36, green: 0.21, blue: 0.09))
                        .frame(height: bh * 0.30).offset(y: bh * 0.52)
                }
        }
        .frame(width: bw, height: bh)
        .clipShape(RoundedRectangle(cornerRadius: bw * 0.09))
    }
}

// BU ŞEKİL: konum işareti (yuvarlak baş + iki teğet çizgiyle sivri uç)
// NASIL: uçtan daireye çizilen teğetlerin değdiği noktalar hesaplanır (açı = arccos(yarıçap / merkez-uç uzaklığı)),
//   daire bu iki nokta arasında ÜSTTEN dolaşılır, sonra uca inilir. 64 noktalık çokgen: göze tam yuvarlak.
// ⮕ KULLANIM [PinShape]: kullanır: YukumLogo
struct PinShape: Shape { // Shape [SWIFT]: kodla çizilen şekil
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + r)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        let a = acos(r / (tip.y - center.y))
        let start = Double.pi / 2 + a, end = Double.pi / 2 - a + 2 * Double.pi
        var path = Path()
        for i in 0...64 {
            let t = start + (end - start) * Double(i) / 64
            let p = CGPoint(x: center.x + r * cos(t), y: center.y + r * sin(t))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.addLine(to: tip)
        path.closeSubpath()
        return path
    }
}

// BU GÖRÜNÜM: üst çubuktaki marka başlığı: logo + "Yüküm" (yönetici notu: "içerde Yüküm yazan yerde de o ikon olmalı")
// ⮕ KULLANIM [BrandTitle]: kullanır: HomeView › toolbar (.principal)
struct BrandTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 6) {
            YukumLogo(size: 26)
            Text("Yüküm").font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette(isDark: colorScheme == .dark).title)
        }
    }
}
