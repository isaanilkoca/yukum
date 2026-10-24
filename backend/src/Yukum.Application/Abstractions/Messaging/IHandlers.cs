namespace Yukum.Application.Abstractions.Messaging;

// CQRS-lite: her kullanım senaryosu bir handler sınıfıdır (MediatR kullanılmaz; controller handler'ı doğrudan DI ile alır).
// Komut durumu DEĞİŞTİRİR, sorgu yalnız OKUR.
public interface ICommandHandler<in TCommand, TResult>
{
    Task<TResult> HandleAsync(TCommand command, CancellationToken cancellationToken = default);
}

public interface IQueryHandler<in TQuery, TResult>
{
    Task<TResult> HandleAsync(TQuery query, CancellationToken cancellationToken = default);
}
