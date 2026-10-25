using Microsoft.AspNetCore.Identity;
using Yukum.Domain.Accounts;
using Yukum.Domain.Common;

namespace Yukum.Infrastructure.Identity;

/// <summary>
/// Sisteme giriş yapabilen kullanıcı (Yük Veren, Taşımacı, Admin). ASP.NET Core Identity'nin kullanıcı sınıfından türer;
/// şifre hash'i, e-posta, telefon, hesap kilidi (5 yanlışta geçici kilit) gibi alanlar hazır gelir.
/// Anahtarı GUID'dir (tahmin edilemez). Ek bilgiler rolüne göre <see cref="ShipperProfile"/> veya <see cref="CarrierProfile"/> tablosundadır.
/// </summary>
// IdentityUser<Guid>'den gelenler: Id, UserName, Email, PhoneNumber, PasswordHash (şifrenin hash'i), LockoutEnd, AccessFailedCount (hatalı deneme sayacı)... Aşağıdakiler bizim eklediklerimiz.
public class AppUser : IdentityUser<Guid>, ITimestamped
{
    /// <summary>Ad-soyad ya da firma adı (ekranda görünen ad).</summary>
    public string FullName { get; set; } = "";

    /// <summary>Kullanıcı türü. Kayıt endpoint'i belirler; istemciden gelmez.</summary>
    public UserType UserType { get; set; }

    /// <summary>Hesap etkin mi? Hesabı silen/dondurulan kullanıcı giriş yapamaz.</summary>
    public bool IsActive { get; set; } = true;

    /// <summary>Yönetici tarafından engellendi mi? Engelli kullanıcı giriş yapamaz.</summary>
    public bool IsBlocked { get; set; }

    /// <summary>Profil fotoğrafının adresi (opsiyonel).</summary>
    public string? AvatarUrl { get; set; }

    /// <summary>KVKK aydınlatma metnini kabul ettiği an (UTC). Kayıt için zorunludur; ne zaman onayladığı kanıt olarak saklanır.</summary>
    public DateTime? KvkkAcceptedAt { get; set; }

    /// <inheritdoc />
    public DateTime CreatedAt { get; set; }

    /// <inheritdoc />
    public DateTime? UpdatedAt { get; set; }
}
