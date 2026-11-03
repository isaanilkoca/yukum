//
//  OldOffersView.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 2.11.2026.
//

import SwiftUI


// BU EKRAN: Yük Veren'in karara bağladığı (kabul/red) tüm teklifler = "Eski teklifler". Satırı kaydırıp kendi listesinden silebilir.
// BAĞLANTI: View/HomeView.swift → Yük Veren'in sol üst saat ikonu bu ekranı açar
// Veri: Network/OfferService.swift → shipperHistory, hide | kalıbı: Network/OfferRequest.swift → ShipperHistoryOffer


struct OldOffersView: View {
    
    // offers: ekranda gösterilecek eski tekliflerin listesi | NE İŞE YARAR: List bunu çizer; değişince ekran yenilenir (@State)
    // NEREDE DOLAR: aşağıdaki loadOffers() API'den çekip buraya yazar | başta boş []
    
    @State private var offers : [ShipperHistoryOffer] = []
    
    // errorMessage: kırmızı hata yazısı | NE İŞE YARAR: yükleme/silme başarısız olursa sebebi gösterir | NEREDE DOLAR: loadOffers() ve hide() catch blokları
     @State private var errorMessage: String? // String? = boş olabilir | nil: hata yok
    
    var body: some View {
    
        VStack(spacing: 16){
            if let errorMessage {Text(errorMessage).foregroundColor(.red)}
            
            if offers.isEmpty{
                Text("Henüz karar verdiğin teklif yok").foregroundColor(.secondary)
            }else {
                List(offers) {offer in
                    VStack(alignment: .leading, spacing: 6){  // bir teklifin satırı | .leading: sola yasla
                     
                        HStack{
                            Text(offer.listingTitle).font(.headline)
                            Spacer()
                            Text("\(Int(offer.amount))₺").bold()
                        }
                        
                        Text("\(offer.fromCityName) / \(offer.fromDistrictName) → \(offer.toCityName) / \(offer.toDistrictName)").font(.subheadline).foregroundColor(.secondary) // rota: il / ilçe → il / ilçe
                                              Text("Taşımacı: \(offer.carrierName)").font(.caption).foregroundColor(.secondary) // teklifi veren Taşımacı | carrierName: backend'in Users tablosundan okuyup gönderdiği ad
                                              Text("\(offer.weightKg) kg · \(offer.pickupDate)").font(.caption).foregroundColor(.secondary) // yük ağırlığı · yükleme tarihi

                                              // karar yazısı | ?: kısa if | Accepted ise yeşil "Kabul ettin", değilse kırmızı "Reddettin"
                                              // (burada yalnız karar verilmişler gelir, "Pending" yok; bu yüzden switch yerine kısa if yeterli)
                                              Text(offer.status == "Accepted" ? "Kabul ettin" : "Reddettin")
                                                  .font(.subheadline).foregroundColor(offer.status == "Accepted" ? .green : .red)
                        
                    }
                    
                    .padding(.vertical, 4) // satırın üst/alt boşluğu
                                    .swipeActions { // .swipeActions [SWIFT]: satırı sola kaydırınca çıkan düğmeler
                                        if offer.status == "Rejected" { // yalnız REDDEDİLEN teklif silinebilir (bitmiş iş) | kabul edilen AKTİF İŞ, silinemez (API de 409 verir) | Accepted satırda kaydırınca düğme çıkmaz
                                            Button("Sil", role: .destructive) { hide(offer) } // role: .destructive: kırmızı silme düğmesi
                                        }
                                    }
                                }.listStyle(.plain) // düz beyaz zemin
                .refreshable { await loadOffers() } // .refreshable [SWIFT]: List'i parmakla AŞAĞI çekince süslü parantezdeki iş çalışır, yenileme çarkı iş bitince kendiliğinden kapanır | await: bitene kadar bekle | NE İŞE YARAR: kullanıcı, otomatik yenilemeyi beklemeden güncel veriyi kendisi ister (her uygulamada bulunan standart davranış)
                }
            }
        
           .padding() // kenarlardan boşluk
           .navigationTitle("Eski Teklifler") // [SWIFT] üst çubuk başlığı
           .navigationBarTitleDisplayMode(.inline)
           .task { await loadOffers() } // .task [SWIFT]: ekran açılınca bir kez çalışır | listeyi yükler
            
        }
    
    // loadOffers: eski teklifleri API'den çekip @State'e yazar | private: yalnız bu ekran görür | ÇAĞIRAN: .task ve hide
     private func loadOffers() async {
         do {
             offers = try await OfferService().shipperHistory() // BAĞLANTI: Network/OfferService.swift → GET /api/v1/offers/history
         } catch let error as AuthError { // API hayır dedi | AuthError: Network/AuthService.swift
             errorMessage = error.message
         } catch { // API kapalı, internet yok
             if Task.isCancelled || (error as? URLError)?.code == .cancelled { return } // İPTAL ≠ HATA: SwiftUI ekran yenilenirken/çıkılırken çalışan .task'ı iptal eder, o işin internet isteği "cancelled" hatası fırlatır | bunu kullanıcıya "Sunucuya ulaşılamadı." diye göstermeyiz | Task.isCancelled: bu iş iptal edildi mi | (error as? URLError): hata internet hatası türüne çevrilebiliyorsa | .code == .cancelled: sebebi iptal | return: sessizce çık
            errorMessage = "Sunucuya ulaşılamadı."
         }
     }
    
    // hide: teklifi KENDİ geçmişimden siler (Taşımacı görmeye devam eder) | offer: hangisi | ÇAĞIRAN: satırdaki Sil düğmesi
       private func hide(_ offer: ShipperHistoryOffer) {
           Task { // Task [SWIFT]: normal fonksiyon içinde await kullanmamızı sağlar
               errorMessage = nil // eski hatayı temizle
               do {
                   try await OfferService().hide(offerId: offer.id) // BAĞLANTI: DELETE /api/v1/offers/{id} | API jetondaki role bakıp Yük Veren tarafını gizler
                   await loadOffers() // silindi, listeyi yeniden çek: satır kaybolur
               } catch let error as AuthError {
                   errorMessage = error.message
               } catch {
                   errorMessage = "Sunucuya ulaşılamadı."
               }
           }
    }
    
}

#Preview {
    OldOffersView()
}
