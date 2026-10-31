//
//  OfferService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 31.10.2026.
//

import Foundation // [SWIFT] ağ araçları (URL, URLRequest, URLSession, JSON) bu kütüphanede

// BU DOSYA: teklif ucuyla konuşur. ListingService gibi istekte jeton taşır.
// GENEL MANTIK (API'ye istek atmak): zarfı hazırla → postacıya ver → cevabı bekle → durum kodunu oku → koda göre davran.
// FONKSİYON HARİTASI: bu dosyadaki create = APİ'YE GÖNDERME + CEVABI ALMA fonksiyonu (zarf hazırla, URLSession ile yolla, durum koduna göre sonucu döndür ya da hata fırlat)
//   akış: düğme (ListingDetailView) → create (burası) → internet → backend OffersController.Create → CreateOfferHandler → DB, cevap aynı yoldan geri döner
// BAĞLANTI: View/ListingDetailView.swift "Teklifi Gönder" düğmesi → OfferService().create(...) | jeton: Network/Session.swift
//           Paket kalıpları: Network/OfferRequest.swift | API tarafı: backend OffersController (POST /api/v1/listings/{id}/offers)

struct OfferService { // struct [SWIFT]: alan+fonksiyon taşıyan kalıp | OfferService [BİZİM] ad

    private let baseURL = "http://localhost:5054" // sunucunun ana adresi | private: yalnız bu struct görür | diğer servislerle aynı (canlıda hepsi birlikte değişecek)

    // create: teklif verir | func [SWIFT]: fonksiyon tanımı | create [BİZİM] ad
    // listingId: hangi ilan | çağırırken "listingId:" yazılır
    // _ body: tutar+not paketi | _ = çağırırken "body:" yazılmaz
    // async: içinde cevap beklenir | throws: hata fırlatabilir | -> offerResponse: başarıda kaydedilen teklifi döner
    // ÇAĞIRAN: View/ListingDetailView.swift "Teklifi Gönder" düğmesi
    func create(listingId: String, _ body: CreatOfferRequest) async throws -> offerResponse {

        // ── 1) KİMLİK: jeton var mı? ──
        guard let token = Session.accessToken else { // Session.accessToken: LoginView girişte yazmıştı | String? = boş olabilir
            // guard let: doluysa "token" adıyla aşağıda kullan | nil ise bu else'e gir (giriş yapılmamış demek)
            throw AuthError(message: "Oturum bulunamadı, tekrar giriş yapın.") // throw: hatayı fırlat, fonksiyon biter | çağıran yerdeki catch yakalar | AuthError: Network/AuthService.swift
        } // guard burada biter: aşağıda token artık dolu

        // ── 2) ZARFI HAZIRLA: nereye, nasıl, ne ile ──
        // URLRequest [SWIFT]: gidecek zarf | var: aşağıda alan ekleyeceğiz, değişebilir
        // URL(string:): yazıyı adrese çevirir | ! = "boş çıkmaz, eminim" | adreste BOŞLUK olursa nil döner ve uygulama çöker
        // \(listingId): yazının içine ilan numarasını koyar → .../listings/ABC123/offers
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/listings/\(listingId)/offers")!)
        request.httpMethod = "POST" // HTTP yöntemi | GET = veri iste | POST = veri gönder, yeni kayıt oluştur
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // başlık (header) = zarfın dışındaki etiket | "içerik JSON" | API bunu okuyup içeriği doğru çözer | ad tam "Content-Type" olmalı, boşluk olmaz
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // kimlik kartı | "Bearer " + jeton | API jetondan kim olduğumuzu ve rolümüzü (Carrier) çıkarır
        request.httpBody = try JSONEncoder().encode(body) // httpBody = zarfın İÇİ | JSONEncoder [SWIFT]: struct'ı JSON yazısına çevirir → {"amount":1200,"note":"..."} | try: çevirme hata verebilir

        // ── 3) GÖNDER ve CEVABI BEKLE ──
        // URLSession.shared [SWIFT]: postacı | .data(for:) zarfı götürür, cevabı getirir
        // await: cevap gelene kadar bu fonksiyon bekler (ekran donmaz) | try: ağ yoksa/sunucu kapalıysa hata fırlatır → ekranda "Sunucuya ulaşılamadı."
        // cevap iki parça: data = içerik (JSON) | response = durum bilgisi | let (a, b) = iki değeri tek seferde ayırır
        let (data, response) = try await URLSession.shared.data(for: request)

        // ── 4) DURUM KODUNU OKU ──
        // response genel tiptir | as? HTTPURLResponse: "HTTP cevabı olarak oku, olamazsa nil" | ?.statusCode: nil değilse kodu al | ?? 0: nil ise 0
        // kodlar: 200 tamam | 400 hatalı istek | 401 jeton yok/bitti | 403 rol uygun değil | 404 ilan yok | 409 ilan kapalı
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        // ── 5) KODA GÖRE DAVRAN ──
        if (200...299).contains(status) { // 200...299 = kapalı aralık | 2xx = başarı
            return try JSONDecoder().decode(offerResponse.self, from: data) // JSONDecoder [SWIFT]: JSON'u struct'a çevirir | offerResponse.self = "bu kalıba çevir" | from: data = gelen içerik | alan adları eşleşmezse hata verir | return: sonucu çağırana verir, fonksiyon biter
        }

        if status == 401 || status == 403 { // 401: jeton yok/süresi bitti (15 dk) | 403: rol uygun değil (Yük Veren teklif veremez) | || = veya
            throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.")
        }

        // buraya geldiyse 400 (hatalı tutar), 404 (ilan yok) ya da 409 (ilan kapalı) gibi bir şey olmuştur
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // API hatayı da JSON gönderir | try?: çevrilemezse hata fırlatma, nil yap | APIErrorResponse: Network/RegisterRequest.swift
        let firstFieldError = apiError?.errors?.values.first?.first // ?. zinciri: biri nil ise hepsi nil | errors: alan→mesaj listesi | ilk alanın ilk mesajı (örn. "Teklif tutarı sıfırdan büyük olmalı.")
        throw AuthError(message: firstFieldError ?? apiError?.detail ?? "Teklif gönderilemedi.") // ?? zinciri: alan mesajı yoksa genel mesaj (detail: örn. "Bu ilan artık teklif almıyor."), o da yoksa sabit yazı
    }
    
    func listingOffers(listingId : String) async throws -> [ListingOffer] {
        guard let token = Session.accessToken else { //jeton yoksa giriş yok
            throw AuthError(message: "Oturum bulunamadı , tekrar giriş yapın.")
        }
        var request = URLRequest(url: URL(string: baseURL +  "/api/v1/listings/\(listingId)/offers")!) // get te yöntem yazilmaz varsayılan get
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // kimlik kartı | GET'te gövde yok, Content-Type gerekmez
        let (data,response) = try await URLSession.shared.data(for: request) // gönder cevabı bekle
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // durum kodu
        if(200...299).contains(status){ return try JSONDecoder().decode([ListingOffer].self, from: data)} // [ListingOffer].self: "liste olarak çevir"
        if status == 401  || status == 403 { throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.") }
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // hata cevabını cevir
        throw AuthError(message: apiError?.detail ?? "Teklifler Alınamadı") // 404 "İlan bulunamadı." gibi mesaj
    }
    // decide: teklifi kabul eder ya da reddeder | accept true → /accept, false → /reject | gövde yok, yalnız POST
    // ÇAĞIRAN: View/ListingOffersView.swift Kabul Et / Reddet düğmeleri
    func decide(offerId : String , accept : Bool) async  throws {
        guard let token = Session.accessToken else {
            throw AuthError(message: "Oturum bulunamadı,tekrar giriş yapın")
        }
        let action = accept ? "accept" : "reject" // ?: kısa if | true ise "accept", değilse "reject" | adresin son parçası
        var request = URLRequest(url: URL(string: baseURL + "/api/v1/offers/\(offerId)/\(action)")!)
        request.httpMethod = "POST" // karar vermek veri değiştirir, POST şart | yazılmazsa GET gider ve API 405 döner
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data,response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200...299).contains(status) {return } // başarıda geri verecek bir şey yok (void) | return : sadece bitir
        if status == 401 || status == 403 {throw AuthError(message: "Oturum süresi doldu ,tekrar giriş yapın")}
        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        throw AuthError(message: apiError?.detail ?? "İşlem yapılamadı.") // 409 " bu teklif icin karar zaten verilmiş gibi
    }
    
}
