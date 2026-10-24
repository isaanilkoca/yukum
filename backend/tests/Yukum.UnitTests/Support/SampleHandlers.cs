using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Domain.Common;

namespace Yukum.UnitTests.Support;

// YALNIZ TEST: handler desenini ve kayıt mekanizmasını denemek için örnekler.
public sealed class SampleItem : BaseEntity
{
    public string Name { get; set; } = "";
}

public sealed record RenameSampleItem(Guid Id, string NewName);

public sealed class RenameSampleItemHandler(IRepository<SampleItem> items, IUnitOfWork unitOfWork)
    : ICommandHandler<RenameSampleItem, bool>
{
    public async Task<bool> HandleAsync(RenameSampleItem command, CancellationToken cancellationToken = default)
    {
        var item = await items.GetByIdAsync(command.Id, cancellationToken: cancellationToken);
        if (item is null) return false;

        item.Name = command.NewName;
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}

public sealed record GetSampleItemName(Guid Id);

public sealed class GetSampleItemNameHandler(IRepository<SampleItem> items)
    : IQueryHandler<GetSampleItemName, string?>
{
    public async Task<string?> HandleAsync(GetSampleItemName query, CancellationToken cancellationToken = default) =>
        (await items.GetByIdAsync(query.Id, asNoTracking: true, cancellationToken))?.Name;
}

// Soyut sınıf kaydedilmemeli.
public abstract class AbstractSampleHandler : ICommandHandler<RenameSampleItem, bool>
{
    public abstract Task<bool> HandleAsync(RenameSampleItem command, CancellationToken cancellationToken = default);
}
