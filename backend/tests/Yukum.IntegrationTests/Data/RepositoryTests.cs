using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Infrastructure;
using Yukum.Infrastructure.Persistence;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

[Collection("SqlServer")]
public class RepositoryTests(SqlServerFixture sql)
{
    // Her scope = ayrı bir "oturum" (ayrı DbContext), gerçek bir istek gibi.
    private static AsyncServiceScope NewSession(TestDatabase db)
    {
        var services = new ServiceCollection();
        services.AddScoped<AppDbContext>(_ => db.NewContext());
        services.AddRepositories();
        return services.BuildServiceProvider().CreateAsyncScope();
    }

    private async Task<TestDatabase> NewDatabaseAsync() => await sql.CreateDatabaseAsync(TimeProvider.System);

    private static async Task<Guid> SeedAsync(TestDatabase db, string name)
    {
        await using var session = NewSession(db);
        var item = new TestItem { Name = name };
        session.ServiceProvider.GetRequiredService<IRepository<TestItem>>().Add(item);
        await session.ServiceProvider.GetRequiredService<IUnitOfWork>().SaveChangesAsync();
        return item.Id;
    }

    [Fact]
    public async Task Added_item_can_be_found_by_id_after_save()
    {
        var db = await NewDatabaseAsync();
        var id = await SeedAsync(db, "a");

        await using var session = NewSession(db);
        var found = await session.ServiceProvider.GetRequiredService<IRepository<TestItem>>().GetByIdAsync(id);

        Assert.NotNull(found);
        Assert.Equal("a", found.Name);
    }

    [Fact]
    public async Task GetById_returns_null_for_unknown_id()
    {
        var db = await NewDatabaseAsync();
        await using var session = NewSession(db);

        Assert.Null(await session.ServiceProvider.GetRequiredService<IRepository<TestItem>>().GetByIdAsync(Guid.NewGuid()));
    }

    [Fact]
    public async Task Changes_to_a_tracked_item_are_saved_without_calling_update()
    {
        var db = await NewDatabaseAsync();
        var id = await SeedAsync(db, "old");

        await using (var session = NewSession(db))
        {
            var item = await session.ServiceProvider.GetRequiredService<IRepository<TestItem>>().GetByIdAsync(id);
            item!.Name = "new";
            await session.ServiceProvider.GetRequiredService<IUnitOfWork>().SaveChangesAsync();
        }

        await using var read = NewSession(db);
        Assert.Equal("new", (await read.ServiceProvider.GetRequiredService<IRepository<TestItem>>().GetByIdAsync(id))!.Name);
    }

    [Fact]
    public async Task Removed_item_is_soft_deleted_and_never_returned()
    {
        var db = await NewDatabaseAsync();
        var id = await SeedAsync(db, "a");
        await SeedAsync(db, "b");

        await using (var session = NewSession(db))
        {
            var repository = session.ServiceProvider.GetRequiredService<IRepository<TestItem>>();
            repository.Remove((await repository.GetByIdAsync(id))!);
            await session.ServiceProvider.GetRequiredService<IUnitOfWork>().SaveChangesAsync();
        }

        await using var read = NewSession(db);
        var repo = read.ServiceProvider.GetRequiredService<IRepository<TestItem>>();
        Assert.Null(await repo.GetByIdAsync(id));                                   // GetById gizler
        Assert.Equal(["b"], (await repo.ListAsync()).Select(i => i.Name));          // List gizler
        Assert.Equal(1, await repo.CountAsync());                                   // Count gizler
        Assert.False(await repo.AnyAsync(i => i.Name == "a"));                      // Any gizler
        // Satır gerçekten silinmedi:
        Assert.Equal(2, await read.ServiceProvider.GetRequiredService<AppDbContext>().Set<TestItem>().IgnoreQueryFilters().CountAsync());
    }

    [Fact]
    public async Task List_Count_and_Any_respect_the_predicate()
    {
        var db = await NewDatabaseAsync();
        await SeedAsync(db, "kırmızı");
        await SeedAsync(db, "mavi");
        await SeedAsync(db, "mavi");

        await using var session = NewSession(db);
        var repo = session.ServiceProvider.GetRequiredService<IRepository<TestItem>>();

        Assert.Equal(3, (await repo.ListAsync()).Count);
        Assert.Equal(2, (await repo.ListAsync(i => i.Name == "mavi")).Count);
        Assert.Equal(3, await repo.CountAsync());
        Assert.Equal(1, await repo.CountAsync(i => i.Name == "kırmızı"));
        Assert.True(await repo.AnyAsync(i => i.Name == "mavi"));
        Assert.False(await repo.AnyAsync(i => i.Name == "yeşil"));
    }

    [Fact]
    public async Task AsNoTracking_does_not_track_the_loaded_items()
    {
        var db = await NewDatabaseAsync();
        var id = await SeedAsync(db, "a");

        await using var session = NewSession(db);
        var context = session.ServiceProvider.GetRequiredService<AppDbContext>();
        var repo = session.ServiceProvider.GetRequiredService<IRepository<TestItem>>();

        await repo.GetByIdAsync(id, asNoTracking: true);
        await repo.ListAsync(asNoTracking: true);
        Assert.Empty(context.ChangeTracker.Entries());

        await repo.GetByIdAsync(id);
        Assert.Single(context.ChangeTracker.Entries());
    }

    [Fact]
    public async Task SaveChanges_is_atomic_a_conflict_saves_nothing()
    {
        var db = await NewDatabaseAsync();
        var id = await SeedAsync(db, "a");

        await using var first = NewSession(db);
        var firstRepo = first.ServiceProvider.GetRequiredService<IRepository<TestItem>>();
        var loaded = await firstRepo.GetByIdAsync(id);               // birinci oturum eski sürümü tutuyor

        await using (var second = NewSession(db))                   // ikinci oturum araya girip değiştiriyor
        {
            var item = await second.ServiceProvider.GetRequiredService<IRepository<TestItem>>().GetByIdAsync(id);
            item!.Name = "second";
            await second.ServiceProvider.GetRequiredService<IUnitOfWork>().SaveChangesAsync();
        }

        loaded!.Name = "first";                                      // birinci oturum eski sürüm üzerinden değiştiriyor...
        firstRepo.Add(new TestItem { Name = "yeni" });               // ...ve aynı kaydetmede yeni kayıt da ekliyor
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(
            () => first.ServiceProvider.GetRequiredService<IUnitOfWork>().SaveChangesAsync());

        await using var read = NewSession(db);
        var all = await read.ServiceProvider.GetRequiredService<IRepository<TestItem>>().ListAsync();
        Assert.Equal(["second"], all.Select(i => i.Name));           // "yeni" kaydedilmedi, "first" yazılmadı
    }
}
