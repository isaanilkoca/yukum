import  Foundation

// ┌─ BAĞLANTI HARİTASI: AccountService ──────────────────────────────────────────
// │ ÇAĞIRAN : ViewModels/AccountViewModel (silme) | ViewModels/AccountInfoViewModel (Hesap Bilgilerim, 15 Kasım)
// │ API     : backend Api/Controllers/AccountController.cs
// │             POST   /api/v1/account/delete   → DeleteAccountHandler
// │             GET    /api/v1/account/me       → GetAccountProfileHandler
// │             PUT    /api/v1/account/me       → UpdateAccountProfileHandler (400 şifre/biçim, 409 numara kayıtlı)
// │             POST   /api/v1/account/avatar   → UploadAvatarHandler (multipart "file")
// │             DELETE /api/v1/account/avatar   → DeleteAvatarHandler
// │ AĞ      : Models/Networking/APIClient (jeton ekleme, 401'de yenileme, hata çevirme orada; burada yalnız "hangi adres, ne gider")
// └──────────────────────────────────────────────────────────────────────
struct AccountService { // struct [SWIFT]: alan + fonksiyon taşıyan kalıp | AccountService [BİZİM] ad
    private let api = APIClient.shared // tüm istekler bu kapıdan geçer (singleton: uygulamada tek örnek)

    // deleteAccount: sendNoContent [BİZİM, APIClient]: 2xx cevabın gövdesini okumaz, hata varsa APIError fırlatır
    // body: DeleteAccountRequest → JSON'a çevrilip isteğin gövdesine konur | .post: POST yöntemi
    // fallback: sunucu açıklama vermezse gösterilecek yazı | sunucu hatası (400 yanlış şifre, 409 devam eden iş) Türkçe mesajıyla gelir
    func deleteAccount(_ body: DeleteAccountRequest) async throws {
        try await api.sendNoContent(.post, "/api/v1/account/delete", body: body, fallback: "Hesap silinemedi.")
    }

    // ─── Hesap Bilgilerim (15 Kasım) ───
    func profile() async throws -> AccountProfile {
        try await api.send(.get, "/api/v1/account/me", fallback: "Hesap bilgileri alınamadı.")
    }
    func update(_ body: UpdateAccountProfileRequest) async throws -> AccountProfile {
        try await api.send(.put, "/api/v1/account/me", body: body, fallback: "Bilgiler kaydedilemedi.")
    }
    // jpeg: telefonda 512 px'e küçültülmüş JPEG (AccountInfoViewModel.prepareAvatar) → sunucu ilk baytlardan JPEG olduğunu doğrular
    func uploadAvatar(jpeg: Data) async throws -> String {
        let response: AvatarResponse = try await api.upload("/api/v1/account/avatar", field: "file", fileName: "avatar.jpg",
                                                            mimeType: "image/jpeg", data: jpeg, fallback: "Fotoğraf yüklenemedi.")
        return response.avatarUrl
    }
    func deleteAvatar() async throws {
        try await api.sendNoContent(.delete, "/api/v1/account/avatar", fallback: "Fotoğraf kaldırılamadı.")
    }
}

extension AccountService: AccountServicing {} // extension [SWIFT]: mevcut türe sonradan uyum ekler | "AccountService bu sözleşmeyi karşılıyor" demek için boş extension yeter
