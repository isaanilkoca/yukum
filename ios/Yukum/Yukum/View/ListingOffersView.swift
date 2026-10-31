//
//  ListingOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import SwiftUI

// BU EKRAN: Yük Veren kendi ilanına basınca açılır. Gelen teklifleri listeler, Kabul Et / Reddet düğmeleri vardır.
// BAĞLANTI: View/HomeView.swift → Yük Veren listesindeki NavigationLink bu ekranı açar ve ilanı verir
// Teklifleri getirir/karar yollar: Network/OfferService.swift → listingOffers, decide | kalıbı: Network/OfferRequest.swift → ListingOffer

struct ListingOffersView: View {
    
    let listing : Listing // dısarıdan verilir : hOMEVİWDAKİ SATIR | HANGİ İLAN OLDUGU
    @State private var offers : [ListingOffer] = []  // @State [SWIFT]: ekranın hafızası | gelen teklifler, başta boş
    @State private var errorMessage : String? // nil hata yok dolu : kırmızı yazılır

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
                        if offer.status == "Pending" {// API durumu yazı gönderir | bekleyen teklifte düğmeler çıkar
                            HStack{
                                // role: .destructive [SWIFT]: kırmızı, "tehlikeli işlem" görünümü
                                // .bordered / .borderedProminent: ZORUNLU, yoksa List'te satırın her yeri düğme olur
                                Button("Reddet"){ decide(offer,accept: false) }.buttonStyle(.borderedProminent).tint(.red) // .borderedProminent: içi dolu düğme | .tint(.red) [SWIFT]: dolgu rengi kırmızı
                                Button("Kabul et"){ decide(offer,accept: true) }.buttonStyle(.borderedProminent).tint(.green) // içi dolu yeşil
                            }
                        }else { // karar verilmemişse durum yazisi
                            
                            Text(offer.status == "Accepted" ? "Kabul Edildi" : "Reddedildi") // kısa if
                                .font(.subheadline).foregroundColor(offer.status == "Accepted" ? .green : .secondary)
                        }
                        
                    }
                    .padding(.vertical,4)
                }.listStyle(.plain)
            }
        }
        .padding()
        .navigationTitle("Gelen Teklifler") // üst cubuk baslıgı
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadOffers() // .task [SWIFT]: ekran açılınca bir kez çalışır | teklifleri yükler
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
