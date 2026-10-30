//
//  ListingService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 30.10.2026.
//

import Foundation // [SWIFT] ağ araçları (URL, URLSession, JSON) bu kütüphanede

// BU DOSYA NE İŞE YARAR? İlan uçlarıyla konuşur. AuthService'ten farkı: istekte jeton (Authorization başlığı) taşır.
// BAĞLANTI: View/CreateListingView.swift → ListingService().create(...) çağırır (düğme bağlanınca) | jeton Network/Session.swift'ten okunur (LoginView yazmıştı)
//           Paket kalıbı: Network/ListingRequest.swift | API tarafı: backend ListingsController (POST /api/v1/listings)
struct ListingService { // struct [SWIFT]: alan+fonksiyon taşıyan kalıp | ListingService [BİZİM] ad

    private let baseURL = "http://localhost:5054" // sunucunun ana adresi | diğer servislerdeki adresle aynı (canlıda hepsi birlikte değişecek)

    // create: ilan açar | async: cevabı bekler | throws: hata fırlatabilir | -> ListingResponse: başarıda oluşan ilanı döner
    // _ body: dışarıdan CreateListingRequest alır (Network/ListingRequest.swift) | _ = çağırırken "body:" yazılmaz
    // ÇAĞIRAN: View/CreateListingView.swift "İlanı Yayınla" düğmesi
    func create(_ body: CreateListingRequest) async throws -> ListingResponse {

        guard let token = Session.accessToken else { // guard let: nil değilse jetonu token'a koy ve devam et | nil ise else'e gir (giriş yok demek)
            throw AuthError(message: "Oturum bulunamadı, tekrar giriş yapın.") // throw: hatayı fırlat, çağıran catch yakalar | AuthError: Network/AuthService.swift'te tanımlı
        } // guard burada biter: aşağıda token artık dolu

        var request = URLRequest(url: URL(string: baseURL + "/api/v1/listings")!) // URLRequest [SWIFT]: gidecek zarf | URL(string:) yazıyı adrese çevirir | ! boş çıkmaz demek | /api/v1/listings = API'deki ilan odası
        request.httpMethod = "POST" // POST: veri gönderiyorum
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // zarfa etiket: içinde JSON var
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // "ben girişliyim" kanıtı | "Bearer " + jeton | API bunu okuyup kim olduğumuzu anlar
        request.httpBody = try JSONEncoder().encode(body) // zarfın içi | JSONEncoder [SWIFT]: struct'ı JSON'a çevirir | try: hata çıkabilir

        let (data, response) = try await URLSession.shared.data(for: request) // URLSession [SWIFT]: postacı | zarfı gönderir, cevabı getirir | await: cevabı bekle | data: cevabın içeriği, response: durum bilgisi
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // as? HTTPURLResponse: HTTP cevabı olarak oku | .statusCode: sunucunun notu (201 oldu, 400 hatalı, 401 yetkisiz) | ?? 0: okunamazsa 0

        if (200...299).contains(status) { // 200...299 = başarı aralığı | 201: ilan oluştu
            return try JSONDecoder().decode(ListingResponse.self, from: data) // JSONDecoder [SWIFT]: JSON'u struct'a çevirir | ListingResponse: Network/ListingRequest.swift
        }

        if status == 401 || status == 403 { // 401: jeton yok/süresi bitti (15 dk) | 403: rol uygun değil (Taşımacı ilan açamaz)
            throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.")
        }

        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // hata cevabını çevir | try?: çevrilemezse nil | APIErrorResponse: Network/RegisterRequest.swift
        let firstFieldError = apiError?.errors?.values.first?.first // ?.: boş değilse devam et | errors'daki ilk alanın ilk mesajı (örn. "Başlık boş olamaz.")
        throw AuthError(message: firstFieldError ?? apiError?.detail ?? "İlan açılamadı.") // ??: soldaki boşsa sağdakine geç (alan hatası → genel mesaj → sabit yazı)
    }
    
    // myListings: giriş yapan Yük Veren'in kendi ilanlarını getirir | -> [MyListing]: ilan listesi döner (kalıbı: Network/ListingRequest.swift)
    // ÇAĞIRAN: View/HomeView.swift (ekran açılınca, sonraki adım) | API: GET /api/v1/listings/mine
    
    func myListings() async throws -> [MyListing] {
        
        guard let token = Session.accessToken else {
            throw AuthError(message: "Oturum bulunmadı , tekrar giriş yapın.") // jeton yoksa giriş yok (create ile aynı kontrol)
        }
        var request = URLRequest(url: URL(string: baseURL +  "/api/v1/listings/mine")!) // /mine = "benim ilanlarım" odası
        
        // httpMethod yazmıyoruz: URLRequest'in varsayılanı GET (veri iste), create'te POST yazmıştık (veri gönder)
        
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // "ben girişliyim" kanıtı | GET'te gövde ve Content-Type yok, gönderecek paket yok
        
        let (data,response) = try await URLSession.shared.data(for: request)// zarfı gönder, cevabı bekle
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0 // sunucunun notu: 200 tamam, 401 jeton yok/süresi bitti, 403 rol uygun değil
        
        if status == 401 || status == 403 {
            throw AuthError(message: "Oturum süresi doldu,tekrar giriş yapın.")
        }
        if status != 200 { // başka bir sorun
            throw AuthError(message: "İlanlar yüklenemedi.")
        }
        return try JSONDecoder().decode([MyListing].self, from: data) // [MyListing].self: "MyListing'lerden oluşan liste" olarak çevir
        
        
        // create ile farkı: create veri gönderiyordu (POST, gövde, Content-Type). Bu sadece veri istiyor (GET), gönderecek paket yok. İkisinde de jeton başlığı aynı.
    }
    
}
