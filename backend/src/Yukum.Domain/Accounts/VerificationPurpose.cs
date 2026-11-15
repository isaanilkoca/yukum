namespace Yukum.Domain.Accounts;

/// <summary>Tek kullanımlık kodun amacı. Veritabanında sayı olarak saklanır; mevcut sayılar değişmez.</summary>
public enum VerificationPurpose
{
    /// <summary>Kayıttan sonra e-posta adresinin kişiye ait olduğunu kanıtlama.</summary>
    EmailVerification = 1,

    /// <summary>Şifremi unuttum: yeni şifre belirleme.</summary>
    PasswordReset = 2
}
