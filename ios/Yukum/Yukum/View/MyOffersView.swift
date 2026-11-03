//
//  MyOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: Taşımacı'nın tüm teklifleri (bekleyen, kabul, red) = "Tekliflerim / eski teklifler". Karar verilmişleri silebilir.
// BAĞLANTI: View/HomeView.swift → Taşımacı'nın sağ üst kutu ikonu (rozetli) bu ekranı açar
//           Veri: Network/OfferService.swift → myOffers, markSeen, hide | kalıbı: Network/OfferRequest.swift → CarrierOffer
struct MyOffersView: View { // MyOffersView [BİZİM] ad | View [SWIFT]: bu bir ekran

    // offers: ekranda gösterilecek tekliflerin listesi | NE İŞE YARAR: List bunu çizer; değişince ekran kendiliğinden yenilenir (@State)
    // NEREDE DOLAR: aşağıdaki loadOffers() API'den çekip buraya yazar | kalıbı: Network/OfferRequest.swift → CarrierOffer | başta boş []
    @State private var offers: [CarrierOffer] = [] // @State [SWIFT]: ekranın hafızası, değişince ekran yenilenir
    // errorMessage: ekrandaki kırmızı hata yazısı | NE İŞE YARAR: yükleme ya da silme başarısız olursa kullanıcıya sebebi gösterir
    // NEREDE DOLAR: loadOffers() ve hide() içindeki catch blokları | yukarıdaki "if let errorMessage" doluysa çizer
    @State private var errorMessage: String? // String? = boş olabilir | nil: hata yok, dolu: kırmızı yazılır

    // chatOffer: sohbeti açılacak teklif | NE İŞE YARAR: Sohbet düğmesi doldurur → aşağıdaki .navigationDestination ChatView'ı açar, nil olunca kapatır
    // NEDEN ayrı değişken: düğme doğrudan sayfa açamaz (List satırında NavigationLink sorun çıkarır); "hangi teklifin sohbeti açık" bilgisini bu tutar | başta nil: sohbet açık değil
    @State private var chatOffer: CarrierOffer? // ? = boş olabilir

    var body: some View { // ekranın içeriği
        VStack(spacing: 16) { // VStack [SWIFT]: elemanları alt alta dizer | spacing: aralarındaki boşluk

            if let errorMessage { Text(errorMessage).foregroundColor(.red) } // if let: errorMessage nil değilse içine gir | doluysa kırmızı yaz, nil ise hiç çizilmez

            if offers.isEmpty { // isEmpty [SWIFT]: liste boş mu | hiç teklif verilmemişse
                Text("Henüz teklif vermedin.").foregroundColor(.secondary) // .secondary [SWIFT]: gri, ikincil yazı rengi | boş durum mesajı
            } else { // liste doluysa satırları çiz

                List(offers) { offer in // List [SWIFT]: kaydırılabilir satır listesi | offers: dizi (CarrierOffer Identifiable olduğu için id: yazmak gerekmez) | offer: o anki teklif (adı bizim)
                    VStack(alignment: .leading, spacing: 6) { // bir teklifin satırı: alt alta | .leading: sola yasla

                        HStack { // HStack [SWIFT]: elemanları yan yana dizer | sol: ilan başlığı + rozet, sağ: tutar
                            Text(offer.listingTitle).font(.headline) // teklif verdiğimiz ilanın başlığı | .headline [SWIFT]: kalın başlık yazısı

                            if offer.isNew { // isNew: API'den gelen true/false | true = Yük Veren karar verdi (kabul/red) AMA Taşımacı henüz bu ekranı açıp görmedi | "bildirim" yerine uygulama içi rozet
                                Text("Yeni").font(.caption2).bold().foregroundColor(.white) // küçük kalın beyaz yazı | .caption2 [SWIFT]: en küçük yazı boyu
                                    .padding(.horizontal, 6).padding(.vertical, 2) // .padding [SWIFT]: yazının etrafında boşluk | .horizontal: sağ-sol | .vertical: üst-alt
                                    .background(Color.red).clipShape(Capsule()) // .background: arka plan rengi | .clipShape(Capsule()): köşeleri tam yuvarlar, hap şekli olur
                            }

                            Spacer() // Spacer [SWIFT]: kalan boşluğu doldurur, sonraki eleman (tutar) sağa yaslanır
                            Text("\(Int(offer.amount)) ₺").bold() // \( ) = yazının içine değişken koyar | Int(): 48000.0 yerine 48000 | .bold(): kalın
                        }

                        Text("\(offer.fromCityName) / \(offer.fromDistrictName) → \(offer.toCityName) / \(offer.toDistrictName)").font(.subheadline).foregroundColor(.secondary) // rota: il / ilçe → il / ilçe | NE İŞE YARAR: ilanın tam güzergâhını gösterir
                                                Text("Yük Veren: \(offer.shipperName)").font(.caption).foregroundColor(.secondary) // ilanı kimin açtığı | .caption: küçük yazı | shipperName: backend'in Users tablosundan okuyup gönderdiği ad
                                                Text("\(offer.weightKg) kg · \(offer.pickupDate)").font(.caption).foregroundColor(.secondary) // yük ağırlığı · yükleme tarihi | · sadece ayırıcı karakter
                        
                        // durum yazısı | switch [SWIFT]: bir değere göre dallanır, çok if/else yerine okunaklı | offer.status API'den yazı gelir
                        switch offer.status {
                        case "Accepted": Text("Kabul edildi").foregroundColor(.green) // case: değer buna eşitse | Yük Veren kabul etti
                        case "Rejected": Text("Reddedildi").foregroundColor(.red) // Yük Veren reddetti
                        default: Text("Beklemede").foregroundColor(.orange) // default: yukarıdakilerin hiçbiri değilse (Pending) | switch'te zorunlu
                        }

                        if offer.status != "Rejected" { // reddedilen teklifte sohbet yok | Pending ve Accepted'da düğme çıkar
                            Button("Sohbet") { chatOffer = offer }.buttonStyle(.bordered) // chatOffer'ı doldurur → ChatView açılır | .bordered: List'te satırın her yeri düğme olmasın diye stil şart
                        }
                    }
                    .padding(.vertical, 4) // satırın üst/alt boşluğu

                    // .swipeActions [SWIFT]: satırı sola kaydırınca çıkan düğmeler
                    .swipeActions {
                        if offer.status == "Rejected" { // yalnız REDDEDİLEN teklif silinebilir (bitmiş iş) | bekleyen: karar yok | kabul edilen: AKTİF İŞ, iki taraf da görmeye ve sohbete devam etmeli (API de 409 verir)
                            Button("Sil", role: .destructive) { hide(offer) } // role: .destructive [SWIFT]: kırmızı "tehlikeli işlem" düğmesi | basınca aşağıdaki hide fonksiyonu | offer: hangi satır
                        }
                    }
                }.listStyle(.plain) // .plain: düz beyaz zemin, ince çizgiler | varsayılan gri zemin olurdu
                .refreshable { await loadOffers() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince süslü parantezdeki iş çalışır, yenileme çarkı iş bitince kendiliğinden kapanır | await: bitene kadar bekle | NE İŞE YARAR: kullanıcı, otomatik yenilemeyi beklemeden güncel veriyi kendisi ister (her uygulamada bulunan standart davranış)
            }
        }
        .padding() // ekranın kenarlarından boşluk
        .navigationTitle("Tekliflerim") // [SWIFT] üst çubuk başlığı | geri oku HomeView'daki NavigationStack'ten otomatik gelir
        .navigationBarTitleDisplayMode(.inline) // [SWIFT]: başlığı küçük, ortada gösterir
        .task { // .task [SWIFT]: ekran açılınca bir kez çalışır | içinde await kullanılabilir
            await loadOffers() // ÖNCE listeyi çek: "Yeni" rozetleri bu sayede çizilir
            try? await OfferService().markSeen() // SONRA "görüldü" yap: sunucuda CarrierSeen=true olur, anasayfadaki rozet söner | BAĞLANTI: Network/OfferService.swift → POST /offers/mine/seen | try?: hata olursa sessiz geç, kritik değil
        }
        // NEDEN .navigationDestination(item:) KULLANDIK, NavigationLink değil?
        //   NavigationLink'i List satırının İÇİNE koyarsak satırın her yeri link olur, içindeki Reddet/Kabul/Sohbet düğmeleri çalışmaz (hepsi sayfaya götürür).
        //   Çözüm: düğme sayfa AÇMAZ, sadece chatOffer değişkenine teklifi YAZAR. Buradaki kural "chatOffer dolunca ChatView'a geç" der.
        //   Akış: Sohbet düğmesi → chatOffer = offer → ekran bunu görür → ChatView açılır | geri okuna basınca SwiftUI chatOffer'ı tekrar nil yapar.
        // item: $chatOffer → "bu değişkeni izle" ($ = bağ, SwiftUI değişkeni hem okur hem sıfırlar) | dolu = geç, nil = kapat
        // Bu çalışsın diye CarrierOffer'ın Hashable olması gerekir (Network/OfferRequest.swift): SwiftUI hangi öğenin seçili olduğunu bununla takip eder.
        // Çalışması için bu ekranın HomeView'daki NavigationStack'in içinde olması yeterli, buraya ayrıca NavigationStack KONMAZ.
        .navigationDestination(item: $chatOffer) {   offer in // $ = bağ | offer: dolan teklif (adı bizim)
            // BAĞLANTI: View/ChatView.swift | title: karşı tarafın adı (ilanı açan Yük Veren) | canWrite: reddedilmemişse yazılabilir
            ChatView(offerId: offer.id, title: offer.shipperName, canWrite: offer.status != "Rejected")
        }
    }

    // loadOffers: teklifleri API'den çekip @State'e yazar | private: yalnız bu ekran görür | async: içinde await var
    // ÇAĞIRAN: yukarıdaki .task ve silme sonrası hide
    private func loadOffers() async {
        do { // do: dene | hata olursa catch'lerden biri çalışır
            offers = try await OfferService().myOffers() // BAĞLANTI: Network/OfferService.swift → GET /api/v1/offers/mine | dönen liste @State'e yazılır, ekran yenilenir
        } catch let error as AuthError { // API hayır dedi (401 vb.) | AuthError: Network/AuthService.swift'te tanımlı
            errorMessage = error.message // mesajı yaz, if let kırmızı Text'i çizer
        } catch { // başka her hata: API kapalı, internet yok
            errorMessage = "Sunucuya ulaşılamadı."
        }
    }

    // hide: teklifi KENDİ geçmişimden siler (karşı taraf görmeye devam eder) | offer: hangisi | ÇAĞIRAN: satırdaki Sil düğmesi
    private func hide(_ offer: CarrierOffer) { // _ : çağırırken ad yazılmaz
        Task { // Task [SWIFT]: normal fonksiyon (async değil) içinde await kullanmamızı sağlar
            errorMessage = nil // eski hatayı temizle
            do {
                try await OfferService().hide(offerId: offer.id) // BAĞLANTI: Network/OfferService.swift → DELETE /api/v1/offers/{id} | offer.id: silinecek teklifin numarası
                await loadOffers() // silindi, listeyi yeniden çek: satır kaybolur
            } catch let error as AuthError {
                errorMessage = error.message // örn. "Bekleyen teklif silinemez; önce karar verilmeli."
            } catch {
                errorMessage = "Sunucuya ulaşılamadı."
            }
        }
    }
}

#Preview { // Xcode önizleme
    MyOffersView()
}
