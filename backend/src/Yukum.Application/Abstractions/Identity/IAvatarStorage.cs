namespace Yukum.Application.Abstractions.Identity;

// ┌─ BAĞLANTI HARİTASI: IAvatarStorage.cs ───────────────────────────────────────
// │ ROL       : profil fotoğrafı DOSYASININ nerede durduğunu iş kuralından gizleyen sözleşme (port)
// │ GERÇEĞİ   : Infrastructure/Identity/LocalAvatarStorage.cs → sunucu diski, klasör "Storage:AvatarPath" (appsettings)
// │ KULLANAN  : Application/Accounts/AccountProfileHandlers.cs → UploadAvatarHandler, DeleteAvatarHandler, GetAvatarHandler
// │             Application/Accounts/DeleteAccountHandler.cs   → hesap silinince fotoğraf dosyası da silinir (KVKK)
// │ DB        : dosya veritabanına YAZILMAZ; DB'de yalnız adresi durur → AspNetUsers.AvatarUrl = "/api/v1/avatars/{id}"
// └──────────────────────────────────────────────────────────────────────
// NEDEN ayrı sözleşme: yayında disk yerine bulut depolama (S3 / Azure Blob) gerekirse yalnız gerçeği (LocalAvatarStorage) değişir;
//   handler'lar, controller ve testler aynı kalır. İş kuralı "dosya nerede" sorusunu bilmez.
// NEDEN id Guid: dosya adı kullanıcıdan GELMEZ (yol enjeksiyonu "../../etc" imkânsız), tahmin edilemez.

/// <summary>Profil fotoğrafı dosyalarının saklandığı yer.</summary>
public interface IAvatarStorage
{
    /// <summary>Dosyayı yeni bir rastgele kimlikle saklar, kimliği döner. <paramref name="contentType"/>: "image/jpeg" ya da "image/png".</summary>
    Task<Guid> SaveAsync(byte[] content, string contentType, CancellationToken cancellationToken = default);

    /// <summary>Dosyayı okur; yoksa null.</summary>
    Task<StoredAvatar?> ReadAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Dosyayı siler; zaten yoksa sessizce geçer.</summary>
    Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
}

/// <summary>Okunan fotoğraf: içerik + türü (cevabın Content-Type başlığı).</summary>
public sealed record StoredAvatar(byte[] Content, string ContentType);
