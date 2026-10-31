//
//  ListingDetail.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import SwiftUI // [SWIFT] ekran çizim kütüphanesi

// BU EKRAN: Taşımacı bir ilana basınca açılan detay ekranı. İlan bilgisini gösterir + teklif formu içerir.
// BAĞLANTI: View/HomeView.swift → Taşımacı listesindeki NavigationLink bu ekranı açar ve ilanı verir
//           Teklif gönderimi: Network/OfferService.swift → create | paket kalıbı: Network/OfferRequest.swift
struct ListingDetailView: View { // ListingDetailView [BİZİM] ad | View [SWIFT]: bu bir ekran

    let listing : Listing  // let [SWIFT]: değişmeyen değer | dışarıdan verilir: HomeView'daki satır | kalıbı: Network/ListingRequest.swift → Listing
    @Environment(\.dismiss) private var dismiss // @Environment [SWIFT]: sistemden hazır değer al | dismiss: "bu ekranı kapat" komutu | teklif gidince ana sayfaya dönmek için
    @State private var amountText = "" // @State [SWIFT]: ekranın hafızası | kullanıcının yazdığı tutar, yazı olarak tutulur (TextField yazıyla çalışır)
    @State private var note = "" // isteğe bağlı not
    @State private var errorMessage: String? // String? = boş olabilir | nil: hata yok, dolu: kırmızı yazılır
    @State private var isLoading = false // istek sürerken true → düğme kilitlenir

    var body: some View { // ekranın içeriği

        VStack(alignment: .leading, spacing: 16) { // alt alta dizer | .leading: sola yasla
            Text(listing.title).font(.title2).bold() // ilan başlığı
            Text("\(listing.fromCityName) / \(listing.fromDistrictName) → \(listing.toCityName) / \(listing.toDistrictName)").font(.headline) // il / ilçe → il / ilçe | \( ) = yazının içine değişken koyar
            Text("Ağırlık : \(Int(listing.weightKg)) kg ") // Int(): ondalığı atar, 9000.0 yerine 9000 | weightKg Double ise gerekir
            Text("Yükleme Tarihi : \(listing.pickupDate)") // API den gelen "yyyy-MM-dd" yazısı

            if let budget = listing.budget { // if let: budget nil değilse içine gir | bütçe isteğe bağlıydı
                Text("Bütçe : \(Int(budget)) TL") // doluysa göster
            }

            Divider() // ince ayırıcı çizgi

            if let offer = listing.myOfferAmount { // daha önce teklif verdiyse
                Text("Mevcut Teklifin: \(Int(offer)) ₺").foregroundColor(.secondary) // Int(): 1200.0 yerine 1200 göster | .secondary [SWIFT]: gri yazı
            }

            // $ = iki yönlü bağ: yazılan doğrudan amountText'e gider | .numberPad: yalnız rakam klavyesi
            TextField("Teklif tutarı (₺)", text: $amountText).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
            TextField("Not (isteğe bağlı)", text: $note).textFieldStyle(.roundedBorder) // not alanı

            if let errorMessage { Text(errorMessage).foregroundColor(.red) } // doluysa kırmızı yaz, nil ise çizilmez

            // FONKSİYON: bu düğmenin kodu = TETİKLEYİCİ | tutarı kontrol eder, paketi hazırlar, OfferService().create'i çağırır (asıl gönderme orada)
            // başarıda dismiss() ile ana sayfaya döner | hatada errorMessage'ı doldurur (kırmızı yazı)
            Button(listing.myOfferAmount == nil ? "Teklifi Gönder" : "Teklifi Güncelle") { // ?: kısa if | == nil ise soldaki yazı, değilse sağdaki | Button [SWIFT]: basınca süslü parantezdeki kod çalışır

                // 1) Kontrol: Int(amountText) yazıyı sayıya çevirir, çeviremezse nil | guard let: sayı varsa "amount" adıyla devam, yoksa else'e gir
                guard let amount = Int(amountText), amount > 0 else {
                    errorMessage = "Geçerli bir tutar gir." // kırmızı yazıyı doldurur, ekran yenilenir
                    return // return: burada dur, aşağısı çalışmaz
                }

                // 2) Paketi hazırla | kalıbı: Network/OfferRequest.swift → CreatOfferRequest | sıra oradaki alan sırasıyla aynı
                // note.isEmpty ? nil : note → boşsa nil gönder (API'de not yok), doluysa yazıyı gönder
                let body = CreatOfferRequest(amount: amount, note: note.isEmpty ? nil : note)

                // 3) API'ye gönder
                Task { // Task [SWIFT]: düğme içinde await kullanmamızı sağlar; ekran donmaz
                    isLo    ading = true // düğme kilitlenir
                    errorMessage = nil // eski hatayı temizle
                    do { // do: dene | hata çıkarsa catch'lerden biri çalışır
                        // BAĞLANTI: Network/OfferService.swift → create → POST /api/v1/listings/{id}/offers
                        // try await: try = hata çıkabilir, await = cevabı bekle | listing.id: hangi ilana teklif verdiğimiz
                        let saved = try await OfferService().create(listingId: listing.id, body)
                        print("Teklif verildi: \(saved.amount)") // geçici test çıktısı (Xcode konsolu)
                        dismiss() // ekranı kapat → ana sayfaya dön
                    } catch let error as AuthError { // API "hayır" dedi (400, 404, 409...) | AuthError: Network/AuthService.swift
                        errorMessage = error.message // kırmızı yazıyı doldurur
                    } catch { // başka her hata: API kapalı, internet yok
                        errorMessage = "Sunucuya ulaşılamadı."
                    }
                    isLoading = false // düğme tekrar açılır
                }
            }
            .buttonStyle(.borderedProminent) // dolu, renkli düğme görünümü
            .disabled(isLoading) // isLoading true iken basılamaz (çift tıklama olmasın)

            Spacer() // kalan boşluğu doldurur, yazılar üste çıkar
        }
        .padding() // kenarlardan boşluk
        .navigationTitle("İlan Detayı") // [SWIFT] üst çubuk başlığı | geri oku NavigationStack'ten otomatik gelir
        .navigationBarTitleDisplayMode(.inline) // [SWIFT]: başlığı küçük, ortada gösterir
    }
}
