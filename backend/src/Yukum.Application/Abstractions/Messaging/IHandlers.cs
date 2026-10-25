namespace Yukum.Application.Abstractions.Messaging;

/// <summary>
/// Durumu DEĞİŞTİREN bir kullanım senaryosunu (komut) işler. Örn. "ilan oluştur", "teklif kabul et".
/// CQRS-lite: her senaryo ayrı bir handler sınıfıdır; MediatR kullanılmaz, controller handler'ı doğrudan DI ile alır.
/// Her komutun yalnızca bir handler'ı olabilir (aksi hâlde uygulama açılırken hata verir).
/// </summary>
/// <typeparam name="TCommand">Komutun girdisi (genelde bir <c>record</c>).</typeparam>
/// <typeparam name="TResult">Komutun sonucu (örn. oluşan kaydın numarası).</typeparam>
public interface ICommandHandler<in TCommand, TResult>
{
    /// <summary>Komutu işler ve sonucu döner.</summary>
    Task<TResult> HandleAsync(TCommand command, CancellationToken cancellationToken = default);
}

/// <summary>
/// Yalnız OKUYAN bir kullanım senaryosunu (sorgu) işler; hiçbir kaydı değiştirmez. Örn. "ilanları listele".
/// </summary>
/// <typeparam name="TQuery">Sorgunun girdisi (filtre, sayfa vb.).</typeparam>
/// <typeparam name="TResult">Sorgunun sonucu.</typeparam>
public interface IQueryHandler<in TQuery, TResult>
{
    /// <summary>Sorguyu işler ve sonucu döner.</summary>
    Task<TResult> HandleAsync(TQuery query, CancellationToken cancellationToken = default);
}
