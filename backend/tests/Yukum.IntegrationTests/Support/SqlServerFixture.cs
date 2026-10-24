using Microsoft.Data.SqlClient;
using Testcontainers.MsSql;

namespace Yukum.IntegrationTests.Support;

// Testin kendi geçici SQL Server'ı (Docker). Tüm veritabanı testleri tek konteyneri paylaşır;
// her test kendi boş veritabanını alır. Geliştirme veritabanına (Yukum) dokunulmaz.
public sealed class SqlServerFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _container = new MsSqlBuilder("mcr.microsoft.com/mssql/server:2025-latest")
        .WithCreateParameterModifier(parameters => parameters.Platform = "linux/amd64")
        .Build();

    public Task InitializeAsync() => _container.StartAsync();

    public Task DisposeAsync() => _container.DisposeAsync().AsTask();

    public string NewDatabaseConnectionString() =>
        new SqlConnectionStringBuilder(_container.GetConnectionString())
        {
            InitialCatalog = "test_" + Guid.NewGuid().ToString("N")
        }.ConnectionString;

    public async Task<TestDatabase> CreateDatabaseAsync(TimeProvider time)
    {
        var database = new TestDatabase(NewDatabaseConnectionString(), time);
        await using var context = database.NewContext();
        await context.Database.EnsureCreatedAsync();
        return database;
    }
}

[CollectionDefinition("SqlServer")]
public class SqlServerCollection : ICollectionFixture<SqlServerFixture>;
