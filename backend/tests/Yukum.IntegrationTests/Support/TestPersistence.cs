using Microsoft.EntityFrameworkCore;
using Yukum.Domain.Common;
using Yukum.Infrastructure.Persistence;

namespace Yukum.IntegrationTests.Support;

// YALNIZ TEST: gerçek tablolar henüz yok; AppDbContext'in ortak davranışını denemek için örnek tablo.
public class TestItem : BaseEntity
{
    public string Name { get; set; } = "";
}

public class TestDbContext(DbContextOptions<TestDbContext> options, TimeProvider time) : AppDbContext(options, time)
{
    public DbSet<TestItem> Items => Set<TestItem>();
}

public sealed class TestDatabase(string connectionString, TimeProvider time)
{
    public string ConnectionString => connectionString;

    public TestDbContext NewContext() =>
        new(new DbContextOptionsBuilder<TestDbContext>().UseSqlServer(connectionString).Options, time);
}
