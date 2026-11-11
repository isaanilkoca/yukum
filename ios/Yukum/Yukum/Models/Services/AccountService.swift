






import  Foundation

// Hesap uçlarıyla konuşur | isteğin kendisi (jeton ekleme, 401'de yenileme, hata çevirme) Models/Networking/APIClient'ta; burada yalnız "hangi adres, ne gider"
// ÇAĞIRAN: AccountViewModel | API: backend AccountController (POST /api/v1/account/delete)
struct AccountService { // struct [SWIFT]: alan + fonksiyon taşıyan kalıp | AccountService [BİZİM] ad
    private let api = APIClient.shared // tüm istekler bu kapıdan geçer (singleton: uygulamada tek örnek)

    // deleteAccount: sendNoContent [BİZİM, APIClient]: 2xx cevabın gövdesini okumaz, hata varsa APIError fırlatır
    // body: DeleteAccountRequest → JSON'a çevrilip isteğin gövdesine konur | .post: POST yöntemi
    // fallback: sunucu açıklama vermezse gösterilecek yazı | sunucu hatası (400 yanlış şifre, 409 devam eden iş) Türkçe mesajıyla gelir
    func deleteAccount(_ body: DeleteAccountRequest) async throws {
        try await api.sendNoContent(.post, "/api/v1/account/delete", body: body, fallback: "Hesap silinemedi.")
    }
}

extension AccountService: AccountServicing {} // extension [SWIFT]: mevcut türe sonradan uyum ekler | "AccountService bu sözleşmeyi karşılıyor" demek için boş extension yeter
