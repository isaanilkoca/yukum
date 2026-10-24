using Microsoft.Extensions.DependencyInjection;
using Yukum.Application;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Infrastructure;
using Yukum.Infrastructure.Persistence;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

[Collection("SqlServer")]
public class HandlerPipelineTests(SqlServerFixture sql)
{
    private static AsyncServiceScope NewSession(TestDatabase db)
    {
        var services = new ServiceCollection();
        services.AddScoped<AppDbContext>(_ => db.NewContext());
        services.AddRepositories();
        services.AddHandlersFromAssembly(typeof(CreateItemHandler).Assembly);
        return services.BuildServiceProvider().CreateAsyncScope();
    }

    [Fact]
    public async Task Command_creates_through_DI_and_query_reads_it_back_in_a_new_session()
    {
        var db = await sql.CreateDatabaseAsync(TimeProvider.System);

        Guid id;
        await using (var write = NewSession(db))
        {
            var create = write.ServiceProvider.GetRequiredService<ICommandHandler<CreateItem, Guid>>();
            id = await create.HandleAsync(new CreateItem("uçtan uca"));
        }

        await using var read = NewSession(db);
        var query = read.ServiceProvider.GetRequiredService<IQueryHandler<GetItemName, string?>>();
        Assert.NotEqual(Guid.Empty, id);
        Assert.Equal("uçtan uca", await query.HandleAsync(new GetItemName(id)));
        Assert.Null(await query.HandleAsync(new GetItemName(Guid.NewGuid())));
    }
}
