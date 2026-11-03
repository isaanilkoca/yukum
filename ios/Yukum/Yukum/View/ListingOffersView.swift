//
//  ListingOffersView.swift
//  Yukum
//  Created by İsa Anıl Koca on 31.10.2026.


import SwiftUI

// BU EKRAN: Yük Veren kendi ilanına basınca açılır. Gelen teklifleri listeler, Kabul Et / Reddet düğmeleri vardır.
// BAĞLANTI: View/HomeView.swift → Yük Veren listesindeki NavigationLink bu ekranı açar ve ilanı verir
// Teklifleri getirir/karar yollar: Network/OfferService.swift → listingOffers, decide | kalıbı: Network/OfferRequest.swift → ListingOffer

struct ListingOffersView: View {
    
    let listing : Listing // dısarıdan verilir : hOMEVİWDAKİ SATIR | HANGİ İLAN OLDUGU
    @State private var offers : [ListingOffer] = []  // @State [SWIFT]: ekranın hafızası | gelen teklifler, başta boş
    @State private var errorMessage : String? // nil hata yok dolu : kırmızı yazılır
    
    // chatOffer: sohbeti açılacak teklif | NE İŞE YARAR: "Sohbet" düğmesi buraya teklifi yazar → aşağıdaki .navigationDestination dolunca ChatView'ı açar, nil olunca kapatır
    // NEDEN ayrı değişken: düğme doğrudan sayfa açamaz (List satırında NavigationLink sorun çıkarır); "hangi teklifin sohbeti açık" bilgisini bu tutar, ChatView'a da buradan verilir
    // NEREDE DOLAR: satırdaki Sohbet düğmeleri | başta nil: sohbet açık değil | ? = boş olabilir demek, nil ile "hiçbiri seçili değil" anlatılır
    
    @State private var chatOffer: ListingOffer? // ? = boş olabilir

    var body: some View {

        VStack(spacing: 16){
            Text(listing.title).font(.title3).bold() // hangi ilan oldugu
            
            if let errorMessage {Text(errorMessage).foregroundColor(.red)}  // doluysa kırmızı yaz, nil ise çizilmez
            if offers.isEmpty { // liste boş mu
                Text("Henüz Teklif gelmedi.").foregroundColor(.secondary)// .secondary [SWIFT]: gri yazı
            } else {
                List(offers) { offer in // List [SWIFT]: kaydırılabilir satır listesi | offer: o anki teklif
                    VStack(alignment: .leading, spacing: 8) {  // bir teklifin satırı: alt alta, sola yaslı
                        HStack{
                            Text(offer.carrierName).font(.headline) // teklifi veren taşımacı
                            Spacer()
                            Text("\(Int(offer.amount))₺") .bold() // Int(): 48000.0 yerine 48000
                        }
                        
                        if let note = offer.note {
                            Text(note).font(.caption).foregroundColor(.secondary) // küçük gri not
                        }
                        if offer.status == "Pending" { // bekleyen teklif: karar düğmeleri + sohbet | API durumu yazı gönderir
                            HStack {
                                // .borderedProminent / .bordered: ZORUNLU, yoksa List'te satırın her yeri düğme olur | .tint [SWIFT]: dolgu rengi
                                Button("Reddet"){ decide(offer,accept: false) }.buttonStyle(.borderedProminent).tint(.red) // kırmızı dolu
                                Button("Kabul et"){ decide(offer,accept: true) }.buttonStyle(.borderedProminent).tint(.green) // yeşil dolu
                                Button("Sohbet") { chatOffer = offer }.buttonStyle(.bordered) // chatOffer'ı doldurur → aşağıdaki .navigationDestination ChatView'ı açar | çerçeveli düğme
                            }
                        } else { // karar verilmişse durum yazısı
                            Text(offer.status == "Accepted" ? "Kabul Edildi" : "Reddedildi") // ?: kısa if
                                .font(.subheadline).foregroundColor(offer.status == "Accepted" ? .green : .secondary)
                            if offer.status == "Accepted" { // yalnız kabul edilende sohbet kalır, reddedilende yok
                                Button("Sohbet") { chatOffer = offer }.buttonStyle(.bordered)
                            }
                        }
                    } // VStack (bir teklifin satırı) burada biter
                    .padding(.vertical,4)
                }.listStyle(.plain)
                .refreshable { await loadOffers() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince süslü parantezdeki iş çalışır, yenileme çarkı iş bitince kendiliğinden kapanır | await: bitene kadar bekle | NE İŞE YARAR: kullanıcı, otomatik yenilemeyi beklemeden güncel veriyi kendisi ister (her uygulamada bulunan standart davranış)
            }
        }
        .padding()
        .navigationTitle("Gelen Teklifler") // üst cubuk baslıgı
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadOffers() // .task [SWIFT]: ekran açılınca bir kez çalışır | teklifleri yükler
        }
        // NEDEN .navigationDestination(item:) KULLANDIK, NavigationLink değil?
        //   NavigationLink'i List satırının İÇİNE koyarsak satırın her yeri link olur, içindeki Reddet/Kabul/Sohbet düğmeleri çalışmaz (hepsi sayfaya götürür).
        //   Çözüm: düğme sayfa AÇMAZ, sadece chatOffer değişkenine teklifi YAZAR. Buradaki kural "chatOffer dolunca ChatView'a geç" der.
        //   Akış: Sohbet düğmesi → chatOffer = offer → ekran bunu görür → ChatView açılır | geri okuna basınca SwiftUI chatOffer'ı tekrar nil yapar.
        // item: $chatOffer → "bu değişkeni izle" ($ = bağ, SwiftUI değişkeni hem okur hem sıfırlar) | dolu = geç, nil = kapat
        // Bu çalışsın diye ListingOffer'ın Hashable olması gerekir (Network/OfferRequest.swift): SwiftUI hangi öğenin seçili olduğunu bununla takip eder.
        // Çalışması için bu ekranın HomeView'daki NavigationStack'in içinde olması yeterli, buraya ayrıca NavigationStack KONMAZ.
        .navigationDestination(item: $chatOffer) { offer in // $ = bağ | offer: dolan teklif (adı bizim)
            // BAĞLANTI: View/ChatView.swift | offerId: hangi sohbet | title: karşı tarafın adı (Taşımacı) | canWrite: reddedilmemişse yazılabilir
            ChatView(offerId: offer.id, title: offer.carrierName, canWrite: offer.status != "Rejected")
        }
    } // body burada biter: aşağıdakiler ekranın yardımcı fonksiyonları

    // loadOffers: teklifleri API'den çekip @State'e yazar | hem açılışta hem karardan sonra çağrılır (liste yenilensin)
    // private [SWIFT]: yalnız bu ekran görür | async: içinde await var | ÇAĞIRAN: yukarıdaki .task ve decide
    private func loadOffers() async {
        do { // do: dene | hata olursa catch'lere geç
            // BAĞLANTI: Network/OfferService.swift → listingOffers → GET /api/v1/listings/{id}/offers
            offers = try await OfferService().listingOffers(listingId: listing.id) // dönen liste @State'e yazılır, ekran yenilenir
        } catch let error as AuthError { // API hayır dedi (404 vb.) | AuthError: Network/AuthService.swift
            errorMessage = error.message // kırmızı yazıyı doldurur
        } catch { // başka her hata: API kapalı, internet yok
            errorMessage = "Sunucuya ulaşılamadı."
        }
    }

    // decide: Kabul Et / Reddet düğmesi | offer: hangi teklif | accept: true kabul, false red
    // Task [SWIFT]: düğme (normal fonksiyon) içinde await kullanmamızı sağlar
    private func decide(_ offer: ListingOffer, accept: Bool) {
        Task {
            errorMessage = nil // eski hatayı temizle
            do {
                // BAĞLANTI: Network/OfferService.swift → decide → POST /api/v1/offers/{id}/accept veya /reject
                try await OfferService().decide(offerId: offer.id, accept: accept)
                await loadOffers() // karar verildi, listeyi yeniden çek (durumlar güncellensin; kabulde diğerleri "Reddedildi" olur)
            } catch let error as AuthError {
                errorMessage = error.message // örn. "Bu teklif için karar zaten verilmiş."
            } catch {
                errorMessage = "Sunucuya ulaşılamadı."
            }
        }
    }
}
