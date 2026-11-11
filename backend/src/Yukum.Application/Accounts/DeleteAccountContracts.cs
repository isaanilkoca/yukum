namespace Yukum.Application.Accounts;

/// <summary>İstemcinin gönderdiği silme onayı: mevcut şifre (çalınmış bir jetonla hesap silinmesin).</summary>
public sealed record DeleteAccountRequest(string? Password);

/// <summary>Komut: kullanıcı kendi hesabını siler (anonimleştirir).</summary>
public sealed record DeleteAccountCommand(Guid UserId, string? Password);
