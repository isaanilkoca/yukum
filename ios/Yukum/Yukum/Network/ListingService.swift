//
//  ListingService.swift
//  Yukum
//
//  Created by İsa Anıl Koca on 30.10.2026.
//

import Foundation

// BU DOSYA NE İŞE YARAR? İlan uçlarıyla konuşur. AuthService'ten farkı: istekte jeton (Authorization başlığı) taşır.
// BAĞLANTI: View/CreateListingView.swift → ListingService().create(...) çağırır | jeton Network/Session.swift'ten okunur (LoginView yazmıştı)

struct ListingService {
    
    private let baseURL = "http://localhost:5054" // diğer servislerdeki adresle aynı (canlıda hepsi birlikte değişecek)

    // create: ilan açar | body: CreateListingRequest (Network/ListingRequest.swift) | döner: ListingResponse
    // ÇAĞIRAN: View/CreateListingView.swift "İlanı Yayınla" düğmesi
    
    func create(_ body: CreateListingRequest) async throws -> ListingResponse { // _ body: çağırırken "body:" yazmayız

        guard let token = Session.accessToken else {  // Session.accessToken nil ise giriş yok demek
            throw AuthError(message: "Oturum bulunamadı, tekrar giriş yapın.") // AuthError: Network/AuthService.swift'te tanımlı, ekran yakalayıp gösterir
        } // guard burada biter: token doluysa aşağıdan devam, token artık kullanılabilir

        var request = URLRequest(url: URL(string: baseURL + "/api/v1/listings")!) // API'deki ilan odası
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") // "ben girişliyim" kanıtı | "Bearer " + jeton | API bunu okuyup kim olduğumuzu anlar
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if (200...299).contains(status) { // 201 = ilan oluştu
            return try JSONDecoder().decode(ListingResponse.self, from: data)
        }

        if status == 401 || status == 403 { // jeton süresi bitmiş (15 dk) ya da rol uygun değil
            throw AuthError(message: "Oturum süresi doldu, tekrar giriş yapın.")
        }

        let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) // hata cevabı: Network/RegisterRequest.swift'teki APIErrorResponse
        let firstFieldError = apiError?.errors?.values.first?.first
        throw AuthError(message: firstFieldError ?? apiError?.detail ?? "İlan açılamadı.")
    }
}
