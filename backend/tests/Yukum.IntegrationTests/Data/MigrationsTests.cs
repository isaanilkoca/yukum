using Microsoft.EntityFrameworkCore;
using Yukum.Infrastructure.Persistence;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

[Collection("SqlServer")]
public class MigrationsTests(SqlServerFixture sql)
{
    private AppDbContext NewContext() => new(
        new DbContextOptionsBuilder<AppDbContext>().UseSqlServer(sql.NewDatabaseConnectionString()).Options,
        TimeProvider.System);

    [Fact]
    public async Task Migrations_apply_cleanly_to_an_empty_database()
    {
        await using var context = NewContext();

        await context.Database.MigrateAsync();

        Assert.Contains(await context.Database.GetAppliedMigrationsAsync(), m => m.EndsWith("_InitialCreate"));
        Assert.Empty(await context.Database.GetPendingMigrationsAsync());
    }

    [Fact]
    public async Task Model_has_no_changes_missing_from_migrations()
    {
        // Birisi modeli değiştirip migration eklemeyi unutursa bu test kırılır.
        await using var context = NewContext();

        Assert.False(context.Database.HasPendingModelChanges());
        await Task.CompletedTask;
    }
}
