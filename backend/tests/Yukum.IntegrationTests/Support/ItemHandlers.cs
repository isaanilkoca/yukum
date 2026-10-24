using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;

namespace Yukum.IntegrationTests.Support;

// YALNIZ TEST: komut → handler → repository → unit of work → SQL Server zincirinin tamamını denemek için.
public sealed record CreateItem(string Name);

public sealed class CreateItemHandler(IRepository<TestItem> items, IUnitOfWork unitOfWork) : ICommandHandler<CreateItem, Guid>
{
    public async Task<Guid> HandleAsync(CreateItem command, CancellationToken cancellationToken = default)
    {
        var item = new TestItem { Name = command.Name };
        items.Add(item);
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return item.Id;
    }
}

public sealed record GetItemName(Guid Id);

public sealed class GetItemNameHandler(IRepository<TestItem> items) : IQueryHandler<GetItemName, string?>
{
    public async Task<string?> HandleAsync(GetItemName query, CancellationToken cancellationToken = default) =>
        (await items.GetByIdAsync(query.Id, asNoTracking: true, cancellationToken: cancellationToken))?.Name;
}
