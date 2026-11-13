//
//  ScreenTape.swift
//  Yukum
//
//  Ekranı boydan boya geçen koli bandı (2B).
//

import SwiftUI    // [SWIFT] ekran çizim kütüphanesi

// ┌─ BAĞLANTI HARİTASI: ScreenTape.swift ─────────────────────────────────────────
// │ GELEN     : Design/TapedBoxBackground.swift → 7 şerit, alttan yukarı
// │ GİDEN     : yok
// │ TEKNİK    : yalnız SwiftUI (renk + gradyan + yazı + maske animasyonu). 3B değil.
// │ REHBER    : Design/00_Rehber_Design.swift (hangi teknik nerede, okuma sırası)
// └──────────────────────────────────────────────────────────────────────

// BU GÖRÜNÜM: ekranı boydan boya geçen, üstünde marka yazısı olan parlak koli bandı.
// NASIL "çekiliyor": bant aslında baştan beri tam boyda çizili; üstüne bir MASKE konur.
//   Maskenin genişliği progress ile 0 → tam boy büyür; yalnız maskenin altındaki kısım görünür → bant uzuyormuş gibi olur.
//   NEDEN ölçekleme (scaleEffect) değil: ölçekleme yazıyı da ezerdi; maske yazıyı bozmaz.
// ⮕ KULLANIM [ScreenTape]: kullanır: TapedBoxBackground › body
struct ScreenTape: View {
    let text: String
    let color: Color
    let fromLeading: Bool   // true: soldan sağa çekilir | false: sağdan sola
    var progress: CGFloat   // 0 = görünmez, 1 = tam çekilmiş

    // ⮕ KULLANIM [body]: SwiftUI çağırır (ekran çizilirken)
    var body: some View {
        GeometryReader { geometry in // [SWIFT] içinde bulunduğu alanın ölçüsünü verir
            let width = geometry.size.width * 1.3 // ekrandan taşsın: eğik durunca kenarda boşluk kalmasın
            ZStack {
                color.opacity(0.93) // bant gövdesi: hafif saydam → altındaki sahne belli belirsiz seçilir
                LinearGradient(colors: [.white.opacity(0.38), .clear, .black.opacity(0.14)],
                               startPoint: .top, endPoint: .bottom) // parlaklık: üstte ışık, altta gölge → plastik bant hissi
                HStack(spacing: 22) { // bandın üstündeki tekrar eden baskı
                    ForEach(0..<7, id: \.self) { _ in
                        Image(systemName: "shippingbox.fill")
                        Text(text).font(.system(size: 17, weight: .heavy, design: .rounded)).tracking(3)
                    }
                }
                .foregroundStyle(.black.opacity(0.55))
                .fixedSize() // yazılar sıkışıp kısalmasın; taşan kısım kırpılır
            }
            .frame(width: width, height: 46)
            .clipped()
            .mask(alignment: fromLeading ? .leading : .trailing) {
                Rectangle().frame(width: width * progress) // maske: bandın görünen uzunluğu
            }
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4) // bant yüzeyden hafif kalkık dursun
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(height: 46)
        .allowsHitTesting(false) // dokunmaları yutmasın (altındaki alanlara basılabilsin)
    }
}
