namespace Yukum.Application.Common;

/// <summary>
/// "İstenen işlem mevcut bir kayıtla çakışıyor" durumu (örn. bu e-posta ile zaten bir hesap var).
/// API katmanı <c>GlobalExceptionHandler</c> ile 409 ProblemDetails cevabına çevirir.
/// Mesaj istemciye olduğu gibi gösterilir, bu yüzden iç ayrıntı içermemelidir.
/// </summary>
/// <param name="message">Kullanıcıya gösterilebilecek kısa Türkçe açıklama.</param>
public sealed class ConflictException(string message) : Exception(message);
