namespace Yukum.Application.Common;

/// <summary>
/// "İstenen kayıt yok" durumu (örn. olmayan bir ilin ilçeleri istendi). İş kuralı kodu bunu fırlatır;
/// API katmanı <c>GlobalExceptionHandler</c> ile 404 ProblemDetails cevabına çevirir.
/// Mesaj istemciye olduğu gibi gösterilir, bu yüzden iç ayrıntı (tablo adı vb.) içermemelidir.
/// </summary>
/// <param name="message">Kullanıcıya gösterilebilecek kısa Türkçe açıklama (örn. "İl bulunamadı.").</param>
public sealed class NotFoundException(string message) : Exception(message);
