using Asp.Versioning;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Accounts;

namespace Yukum.Api.Controllers;

// ┌─ BAĞLANTI HARİTASI: AccountController.cs ────────────────────────────────────
// │ GELEN (iOS): Models/Services/AccountService.swift (silme, hesap bilgileri, fotoğraf) | Design/AvatarView.swift (fotoğraf GET)
// │ GİDEN      : Application/Accounts/DeleteAccountHandler.cs, AccountProfileHandlers.cs (iş kuralları burada DEĞİL, handler'da)
// │ YETKİ      : [Authorize] → iki rol de; kullanıcı kimliği HER ZAMAN jetondaki "sub"dan (istemci başkasının Id'sini gönderemez)
// └──────────────────────────────────────────────────────────────────────
// ZİNCİR (genel): HTTP isteği → UseAuthentication (jeton çözülür) → UseAuthorization ([Authorize]) → bu metot
//   → handler.HandleAsync → (IAccountService → EF Core → SQL Server) / (IAvatarStorage → disk)
//   → hata olursa GlobalExceptionHandler: ValidationException → 400, ConflictException → 409, NotFoundException → 404 (ProblemDetails)

/// <summary>Hesap işlemleri (giriş yapmış kullanıcının kendisi için).</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/account")]
[Authorize] // iki rol de
public class AccountController(
    ICommandHandler<DeleteAccountCommand, bool> deleteAccount,
    IQueryHandler<GetAccountProfileQuery, AccountProfileDto> getProfile,
    ICommandHandler<UpdateAccountProfileCommand, AccountProfileDto> updateProfile,
    ICommandHandler<UploadAvatarCommand, string> uploadAvatar,
    ICommandHandler<DeleteAvatarCommand, bool> deleteAvatar,
    IQueryHandler<GetAvatarQuery, StoredAvatar?> getAvatar) : ControllerBase
{
    /// <summary>Hesabı siler (anonimleştirir). Şifre onayı ister; devam eden işi olan kullanıcı silemez.</summary>
    // POST /api/v1/account/delete  gövde: { "password": "..." }
    // FONKSİYON ROLÜ: API'NİN KAPISI | iOS'taki AccountService.delete'in isteğini karşılar | DELETE yerine POST: gövde (şifre) taşıyan silme isteklerini bazı istemci/araçlar düşürür
    // Hız sınırı "auth" politikası: çalınmış jetonla şifre tahmin etme denemesini yavaşlatır
    [HttpPost("delete")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Delete(DeleteAccountRequest request, CancellationToken cancellationToken)
    {
        await deleteAccount.HandleAsync(new DeleteAccountCommand(CurrentUserId, request.Password), cancellationToken);
        return NoContent();
    }

    /// <summary>Hesap Bilgilerim: ad, e-posta, telefon, fotoğraf adresi ve rol profili.</summary>
    // GET /api/v1/account/me → 200 AccountProfileDto
    [HttpGet("me")]
    [ProducesResponseType<AccountProfileDto>(StatusCodes.Status200OK)]
    public async Task<IActionResult> Me(CancellationToken cancellationToken) =>
        Ok(await getProfile.HandleAsync(new GetAccountProfileQuery(CurrentUserId), cancellationToken));

    /// <summary>Hesap bilgilerini günceller. Telefon değişiyorsa currentPassword zorunlu (yanlışsa 400). Numara aynı rolde kayıtlıysa 409.</summary>
    // PUT /api/v1/account/me  gövde: UpdateAccountProfileRequest → 200 güncel AccountProfileDto
    // Hız sınırı "auth": gövdede şifre olabilir → şifre denemesi yavaşlatılır (DeleteAccount ile aynı neden)
    [HttpPut("me")]
    [EnableRateLimiting("auth")]
    [ProducesResponseType<AccountProfileDto>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Update(UpdateAccountProfileRequest request, CancellationToken cancellationToken) =>
        Ok(await updateProfile.HandleAsync(new UpdateAccountProfileCommand(CurrentUserId, request), cancellationToken));

    /// <summary>Profil fotoğrafı yükler (multipart/form-data, alan adı "file"; JPEG/PNG, en çok 2 MB). Yeni adresi döner.</summary>
    // POST /api/v1/account/avatar → 200 { "avatarUrl": "/api/v1/avatars/{id}" }
    // RequestSizeLimit: Kestrel 2 MB + çok parçalı başlık payını aşan gövdeyi OKUMADAN keser (bellek şişirme saldırısı). Asıl 2 MB kuralı handler'da.
    // IFormFile [ASP.NET]: multipart gövdedeki dosya parçası.
    // NEDEN parametre DEĞİL, Request.ReadFormAsync: IFormFile parametresi [ApiController]'da otomatik [Consumes("multipart/form-data")] ekler;
    //   bu yönlendirme aşamasında çalışır → yanlış biçimli istek JETON KONTROLÜNDEN ÖNCE 415 alırdı (AuthorizationMatrixTests yakaladı).
    //   Form metot içinde okunursa sıra doğru olur: önce 401/403, sonra biçim (yanlış biçim → "Fotoğraf seçilmedi." 400).
    [HttpPost("avatar")]
    [RequestSizeLimit(AvatarImage.MaxBytes + 64 * 1024)]
    [ProducesResponseType<AvatarResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UploadAvatar(CancellationToken cancellationToken)
    {
        var file = Request.HasFormContentType ? (await Request.ReadFormAsync(cancellationToken)).Files["file"] : null;
        byte[] content = [];
        if (file is not null && file.Length <= AvatarImage.MaxBytes)
        {
            using var buffer = new MemoryStream();
            await file.CopyToAsync(buffer, cancellationToken);
            content = buffer.ToArray();
        }
        else if (file is not null) content = new byte[AvatarImage.MaxBytes + 1]; // büyük dosya belleğe alınmaz; handler "en fazla 2 MB" der
        var url = await uploadAvatar.HandleAsync(new UploadAvatarCommand(CurrentUserId, content), cancellationToken);
        return Ok(new AvatarResponse(url));
    }

    /// <summary>Profil fotoğrafını kaldırır (yoksa da 204).</summary>
    // DELETE /api/v1/account/avatar → 204
    [HttpDelete("avatar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RemoveAvatar(CancellationToken cancellationToken)
    {
        await deleteAvatar.HandleAsync(new DeleteAvatarCommand(CurrentUserId), cancellationToken);
        return NoContent();
    }

    /// <summary>Fotoğrafın kendisi (resim baytları). Giriş yapmış herkes görebilir (ileride Taşımacı profilinde karşı taraf da görecek).</summary>
    // GET /api/v1/avatars/{id} → 200 image/jpeg|png | 404
    // "~/" ile başlayan rota sınıfın "account" önekini yok sayar → adres /api/v1/avatars/{id} (AvatarPath.For ile aynı).
    // Cache-Control: genel "no-store" (Program.cs) burada EZİLİR: aynı id'nin içeriği hiç değişmez (yeni fotoğraf = yeni id),
    //   telefon bir kez indirip saklayabilir. "private": yalnız telefon saklar, ara sunucular saklamaz.
    [HttpGet("~/api/v{version:apiVersion}/avatars/{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Avatar(Guid id, CancellationToken cancellationToken)
    {
        if (await getAvatar.HandleAsync(new GetAvatarQuery(id), cancellationToken) is not { } avatar) return NotFound();
        Response.Headers.CacheControl = "private, max-age=31536000, immutable";
        return File(avatar.Content, avatar.ContentType);
    }

    private Guid CurrentUserId => Guid.Parse(User.FindFirst("sub")!.Value);
}

/// <summary>Fotoğraf yükleme cevabı.</summary>
public sealed record AvatarResponse(string AvatarUrl);
