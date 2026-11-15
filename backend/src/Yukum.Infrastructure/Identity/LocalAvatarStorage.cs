using Microsoft.Extensions.Configuration;
using Yukum.Application.Abstractions.Identity;

namespace Yukum.Infrastructure.Identity;

// ┌─ BAĞLANTI HARİTASI: LocalAvatarStorage.cs ───────────────────────────────────
// │ SÖZLEŞME  : Application/Abstractions/Identity/IAvatarStorage.cs
// │ KAYIT     : Infrastructure/DependencyInjection.cs → AddAccounts() içinde singleton
// │ AYAR      : "Storage:AvatarPath" (yoksa {ContentRoot}/App_Data/avatars) | testler geçici klasör verir (YukumApiFactory)
// │ DİSK      : {klasör}/{guid}.jpg ya da {guid}.png — uzantı içerik türünden; okurken iki uzantıya da bakılır
// └──────────────────────────────────────────────────────────────────────
// NEDEN singleton: durumu yok (yalnız klasör yolu); her istekte yeniden kurmaya gerek yok.
// NEDEN wwwroot/statik dosya DEĞİL: statik klasör herkese (jetonsuz) açılır; fotoğraflar AccountController.Avatar (GET /api/v1/avatars/{id}) üzerinden [Authorize] ile verilir.
// YAYINDA: konteyner diski geçicidir → bu klasör kalıcı bir birime (volume) bağlanmalı ya da sözleşme bulut depolamayla gerçeklenmeli.

/// <summary>Profil fotoğraflarını sunucu diskinde saklar.</summary>
public sealed class LocalAvatarStorage : IAvatarStorage
{
    private readonly string _root;

    public LocalAvatarStorage(IConfiguration configuration)
    {
        _root = configuration["Storage:AvatarPath"] is { Length: > 0 } path
            ? path
            : Path.Combine(configuration["contentRoot"] ?? AppContext.BaseDirectory, "App_Data", "avatars");
        // "contentRoot": ASP.NET Core'un ayarlara koyduğu proje klasörü (backend/src/Yukum.Api). Infrastructure Hosting paketine bağımlı olmasın diye buradan okunur.
        Directory.CreateDirectory(_root); // yoksa açılışta oluşturulur (varsa dokunmaz)
    }

    /// <inheritdoc />
    public async Task<Guid> SaveAsync(byte[] content, string contentType, CancellationToken cancellationToken = default)
    {
        var id = Guid.NewGuid();
        await File.WriteAllBytesAsync(PathOf(id, Extension(contentType)), content, cancellationToken);
        return id;
    }

    /// <inheritdoc />
    public async Task<StoredAvatar?> ReadAsync(Guid id, CancellationToken cancellationToken = default)
    {
        foreach (var (ext, type) in Types)
        {
            var path = PathOf(id, ext);
            if (File.Exists(path)) return new StoredAvatar(await File.ReadAllBytesAsync(path, cancellationToken), type);
        }
        return null;
    }

    /// <inheritdoc />
    public Task DeleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        foreach (var (ext, _) in Types) File.Delete(PathOf(id, ext)); // File.Delete: dosya yoksa hata vermez
        return Task.CompletedTask;
    }

    private static readonly (string Ext, string Type)[] Types = [(".jpg", "image/jpeg"), (".png", "image/png")];
    private static string Extension(string contentType) => Types.First(t => t.Type == contentType).Ext;
    // Dosya adı yalnız Guid'den üretilir ("N" = 32 onaltılık karakter): kullanıcı girdisi yola hiç karışmaz.
    private string PathOf(Guid id, string ext) => Path.Combine(_root, id.ToString("N") + ext);
}
