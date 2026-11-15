using FluentValidation;
using FluentValidation.Results;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Application.Accounts;

// ─── HESAP BİLGİLERİM + PROFİL FOTOĞRAFI (15 Kasım, yönetici planı 7. adım) ───────────────────────────────────────────
// ┌─ BAĞLANTI HARİTASI: AccountProfileHandlers.cs ───────────────────────────────
// │ GELEN     : Api/Controllers/AccountController.cs
// │               GET    /api/v1/account/me       → GetAccountProfileHandler
// │               PUT    /api/v1/account/me       → UpdateAccountProfileHandler (+ UpdateAccountProfileValidator)
// │               POST   /api/v1/account/avatar   → UploadAvatarHandler   (multipart, alan adı "file")
// │               DELETE /api/v1/account/avatar   → DeleteAvatarHandler
// │               GET    /api/v1/avatars/{id}     → GetAvatarHandler      (fotoğrafın kendisi; giriş yapmış herkes)
// │ GİDEN     : IAccountService (Infrastructure/Identity/AccountService.cs) → AspNetUsers + ShipperProfiles / CarrierProfiles tabloları
// │             IAvatarStorage  (Infrastructure/Identity/LocalAvatarStorage.cs) → disk
// │ iOS       : Models/Services/AccountService.swift → ViewModels/AccountInfoViewModel.swift → Views/AccountInfoView.swift
// └──────────────────────────────────────────────────────────────────────
// KURALLAR:
//   - E-posta DEĞİŞTİRİLEMEZ: doğrulama e-postası altyapısı yok; doğrulamasız değişiklik hesap ele geçirmeye kapı açar.
//   - Telefon değişirse MEVCUT ŞİFRE istenir: telefon giriş bilgisidir, SMS doğrulaması yok → çalınmış bir jetonla giriş bilgisi
//     değiştirilemesin. Aynı rolde başka hesaptaki numara → 409 (AspNetUsers'ta (PhoneNumber, UserType) benzersiz indeksi).
//   - Rol alanları: Yük Veren → firma, vergi no, vergi dairesi, il, hakkımda | Taşımacı → il (HomeCityId), hakkımda.
//     Diğer rolün alanı gönderilirse YOK SAYILIR (hata değil: iOS iki rolde tek gövde kullanır).
//   - Puan / tamamlanan iş yalnız okunur (karşı tarafların verdiği puanlardan hesaplanır, kullanıcı değiştiremez).
//   - Fotoğraf: JPEG ya da PNG, en çok 2 MB; tür UZANTIYA/başlığa değil dosyanın İLK BAYTLARINA bakılarak anlaşılır (AvatarImage.Detect).
//     Yeni fotoğraf yüklenince eskisi diskten silinir.

/// <summary>Hesap Bilgilerim ekranının okuduğu her şey. Rolün kullanmadığı alanlar null gelir.</summary>
public sealed record AccountProfileDto(
    Guid Id, string Role, string FullName, string Email, string Phone, string? AvatarUrl,
    int? CityId, string? About,
    string? CompanyName, string? TaxNumber, string? TaxOffice,            // yalnız Yük Veren
    decimal? AverageRating, int? RatingCount, int? CompletedJobCount);     // yalnız Taşımacı (salt okunur)

/// <summary>İstemcinin gönderdiği gövde (PUT /account/me). CurrentPassword yalnız telefon değişiyorsa gerekir.</summary>
public sealed record UpdateAccountProfileRequest(
    string? FullName, string? Phone, string? CurrentPassword, int? CityId, string? About,
    string? CompanyName, string? TaxNumber, string? TaxOffice);

/// <summary>Komut: kim (jetondan) + ne (gövde). Phone handler'da +90 biçimine çevrilir.</summary>
public sealed record UpdateAccountProfileCommand(Guid UserId, UpdateAccountProfileRequest Body);

public sealed record GetAccountProfileQuery(Guid UserId);
public sealed record UploadAvatarCommand(Guid UserId, byte[] Content);
public sealed record DeleteAvatarCommand(Guid UserId);
public sealed record GetAvatarQuery(Guid AvatarId);

/// <summary>Fotoğraf adresinin tek kaynağı: DB'ye bu yazılır, iOS bunu taban adrese ekleyip ister.</summary>
public static class AvatarPath
{
    // NEDEN göreli adres: telefon API'ye bazen Wi-Fi (192.168…), bazen hotspot (172.20…) adresiyle ulaşıyor; tam adres DB'ye yazılsaydı eskirdi.
    public static string For(Guid id) => $"/api/v1/avatars/{id}";

    /// <summary>"/api/v1/avatars/{id}" → id (eski dosyayı silmek için). Biçim tutmazsa null.</summary>
    public static Guid? IdOf(string? url) =>
        url is not null && Guid.TryParse(url[(url.LastIndexOf('/') + 1)..], out var id) ? id : null;
}

/// <summary>Dosyanın gerçekten resim olup olmadığını ilk baytlardan anlar ("sihirli sayı").</summary>
public static class AvatarImage
{
    public const int MaxBytes = 2 * 1024 * 1024; // 2 MB: iOS zaten 512 px JPEG'e küçültüp ~50-150 KB gönderir; sınır kötü niyetli büyük yüklemeye karşı

    // NEDEN içerik kontrolü: uzantı ya da Content-Type istemcinin beyanıdır, sahtelenebilir ("foto.jpg" adında bir betik).
    //   JPEG her zaman FF D8 FF ile, PNG 89 'P' 'N' 'G' 0D 0A 1A 0A ile başlar.
    public static string? Detect(byte[] content) => content switch
    {
        [0xFF, 0xD8, 0xFF, ..] => "image/jpeg",
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ..] => "image/png",
        _ => null
    };
}

/// <summary>PUT /account/me alan kuralları. Ortak kurallar (ad, telefon, il) kayıtla aynı: AccountRules (RegisterValidators.cs).</summary>
public sealed class UpdateAccountProfileValidator : AbstractValidator<UpdateAccountProfileCommand>
{
    public UpdateAccountProfileValidator(IGeographyRepository geography)
    {
        RuleFor(c => c.Body.FullName).FullName().OverridePropertyName("fullName");
        RuleFor(c => c.Body.Phone).Phone().OverridePropertyName("phone");
        RuleFor(c => c.Body.CityId).OptionalExistingCity(geography).OverridePropertyName("cityId");
        // OverridePropertyName: hata anahtarı "Body.FullName" değil "fullName" olsun → iOS hatayı doğru alanın altına yazar.
        RuleFor(c => c.Body.About).Must(v => v!.Trim().Length <= 1000).When(c => c.Body.About is not null)
            .WithMessage("Hakkımda en fazla 1000 karakter olabilir.").OverridePropertyName("about");
        RuleFor(c => c.Body.CompanyName).Must(v => v!.Trim().Length <= 200).When(c => c.Body.CompanyName is not null)
            .WithMessage("Firma adı en fazla 200 karakter olabilir.").OverridePropertyName("companyName");
        RuleFor(c => c.Body.TaxOffice).Must(v => v!.Trim().Length <= 100).When(c => c.Body.TaxOffice is not null)
            .WithMessage("Vergi dairesi en fazla 100 karakter olabilir.").OverridePropertyName("taxOffice");
        RuleFor(c => c.Body.TaxNumber).Must(v => v!.Trim() is { Length: 10 or 11 } t && t.All(char.IsAsciiDigit))
            .When(c => !string.IsNullOrWhiteSpace(c.Body.TaxNumber))
            .WithMessage("Vergi numarası 10 veya 11 haneli rakamlardan oluşmalı.").OverridePropertyName("taxNumber");
    }
}

// ZİNCİR (okuma): iOS AccountInfoViewModel.load() → GET /account/me → AccountController.Me → bu handler
//   → AccountService.GetProfileAsync: AspNetUsers + rolüne göre ShipperProfiles ya da CarrierProfiles (tek kullanıcı, iz sürmeden okuma)
public sealed class GetAccountProfileHandler(IAccountService accounts) : IQueryHandler<GetAccountProfileQuery, AccountProfileDto>
{
    public Task<AccountProfileDto> HandleAsync(GetAccountProfileQuery query, CancellationToken cancellationToken = default) =>
        accounts.GetProfileAsync(query.UserId, cancellationToken);
}

// ZİNCİR (yazma): iOS AccountInfoViewModel.save() → PUT /account/me → AccountController.Update → bu handler
//   1) validator (biçim) → 400  2) telefon değişti mi? → şifre kontrolü → 400  3) AccountService.UpdateProfileAsync (çakışma → 409)
//   4) güncel profil döner → iOS ekranı ve oturumdaki görünen adı yeniler.
public sealed class UpdateAccountProfileHandler(
    IValidator<UpdateAccountProfileCommand> validator, IAccountService accounts) : ICommandHandler<UpdateAccountProfileCommand, AccountProfileDto>
{
    public async Task<AccountProfileDto> HandleAsync(UpdateAccountProfileCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        PhoneNumberNormalizer.TryNormalize(command.Body.Phone, out var phone); // validator geçtiyse çevrilebilir: "0532 …" → "+90532…"

        var current = await accounts.GetProfileAsync(command.UserId, cancellationToken);
        if (phone != current.Phone)
        {
            // 401 DEĞİL 400 (DeleteAccountHandler ile aynı NEDEN): iOS 401'i "oturum bitti" sayar; yanlış şifre oturumu kapatmamalı.
            if (string.IsNullOrEmpty(command.Body.CurrentPassword))
                throw new ValidationException([new ValidationFailure("currentPassword", "Telefonu değiştirmek için mevcut şifreni gir.")]);
            if (!await accounts.VerifyPasswordAsync(command.UserId, command.Body.CurrentPassword, cancellationToken))
                throw new ValidationException([new ValidationFailure("currentPassword", "Şifre hatalı.")]);
        }

        // Boşluklar kırpılır, boş metin "yok" (null) sayılır → DB'de "" ile null karışmaz.
        static string? Clean(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
        var b = command.Body;
        await accounts.UpdateProfileAsync(command.UserId,
            new UpdateAccountProfileRequest(b.FullName!.Trim(), phone, null, b.CityId, Clean(b.About),
                Clean(b.CompanyName), Clean(b.TaxNumber), Clean(b.TaxOffice)), cancellationToken);
        return await accounts.GetProfileAsync(command.UserId, cancellationToken);
    }
}

// ZİNCİR (fotoğraf yükleme): iOS PhotosPicker → 512 px JPEG → AccountService.swift uploadAvatar (multipart) → POST /account/avatar
//   → AccountController.UploadAvatar (2 MB sınırı, dosyayı byte[] yapar) → bu handler:
//   1) boyut + içerik kontrolü → 400  2) IAvatarStorage.SaveAsync → diske yeni Guid adla yazılır
//   3) AccountService.SetAvatarAsync → AspNetUsers.AvatarUrl = "/api/v1/avatars/{id}" (eski adres döner)  4) eski dosya silinir
//   → yeni adres iOS'a döner, ekran resmi yeniler.
public sealed class UploadAvatarHandler(IAccountService accounts, IAvatarStorage storage) : ICommandHandler<UploadAvatarCommand, string>
{
    public async Task<string> HandleAsync(UploadAvatarCommand command, CancellationToken cancellationToken = default)
    {
        if (command.Content.Length == 0)
            throw new ValidationException([new ValidationFailure("file", "Fotoğraf seçilmedi.")]);
        if (command.Content.Length > AvatarImage.MaxBytes)
            throw new ValidationException([new ValidationFailure("file", "Fotoğraf en fazla 2 MB olabilir.")]);
        var contentType = AvatarImage.Detect(command.Content)
            ?? throw new ValidationException([new ValidationFailure("file", "Yalnız JPEG ya da PNG fotoğraf yüklenebilir.")]);

        var id = await storage.SaveAsync(command.Content, contentType, cancellationToken);
        string? old;
        try
        {
            old = await accounts.SetAvatarAsync(command.UserId, AvatarPath.For(id), cancellationToken);
        }
        catch
        {
            await storage.DeleteAsync(id, CancellationToken.None); // DB'ye yazılamadıysa diskte sahipsiz dosya kalmasın
            throw;
        }
        if (AvatarPath.IdOf(old) is { } oldId) await storage.DeleteAsync(oldId, cancellationToken);
        return AvatarPath.For(id);
    }
}

// ZİNCİR (fotoğrafı kaldır): DELETE /account/avatar → AvatarUrl = null → dosya silinir. Fotoğraf yoksa da 204 (tekrar basmak hata değil).
public sealed class DeleteAvatarHandler(IAccountService accounts, IAvatarStorage storage) : ICommandHandler<DeleteAvatarCommand, bool>
{
    public async Task<bool> HandleAsync(DeleteAvatarCommand command, CancellationToken cancellationToken = default)
    {
        var old = await accounts.SetAvatarAsync(command.UserId, null, cancellationToken);
        if (AvatarPath.IdOf(old) is { } oldId) await storage.DeleteAsync(oldId, cancellationToken);
        return true;
    }
}

// ZİNCİR (fotoğrafı göster): iOS AvatarView → GET /api/v1/avatars/{id} (Bearer jetonla) → diskten okunur. Yoksa null → controller 404.
public sealed class GetAvatarHandler(IAvatarStorage storage) : IQueryHandler<GetAvatarQuery, StoredAvatar?>
{
    public Task<StoredAvatar?> HandleAsync(GetAvatarQuery query, CancellationToken cancellationToken = default) =>
        storage.ReadAsync(query.AvatarId, cancellationToken);
}
