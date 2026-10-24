using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Time.Testing;
using Yukum.IntegrationTests.Support;

namespace Yukum.IntegrationTests.Data;

[Collection("SqlServer")]
public class AppDbContextTests(SqlServerFixture sql)
{
    private static readonly DateTimeOffset T0 = new(2026, 10, 25, 9, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Add_assigns_id_and_CreatedAt_and_leaves_UpdatedAt_empty()
    {
        var time = new FakeTimeProvider(T0);
        var db = await sql.CreateDatabaseAsync(time);

        await using (var context = db.NewContext())
        {
            context.Items.Add(new TestItem { Name = "a" });
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        var item = await read.Items.SingleAsync();
        Assert.NotEqual(Guid.Empty, item.Id);
        Assert.Equal(T0.UtcDateTime, item.CreatedAt);
        Assert.Null(item.UpdatedAt);
        Assert.False(item.IsDeleted);
    }

    [Fact]
    public async Task Update_sets_UpdatedAt_and_keeps_CreatedAt()
    {
        var time = new FakeTimeProvider(T0);
        var db = await sql.CreateDatabaseAsync(time);
        await using (var context = db.NewContext())
        {
            context.Items.Add(new TestItem { Name = "a" });
            await context.SaveChangesAsync();
        }

        time.Advance(TimeSpan.FromHours(2));
        await using (var context = db.NewContext())
        {
            var item = await context.Items.SingleAsync();
            item.Name = "b";
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        var saved = await read.Items.SingleAsync();
        Assert.Equal("b", saved.Name);
        Assert.Equal(T0.UtcDateTime, saved.CreatedAt);
        Assert.Equal(T0.AddHours(2).UtcDateTime, saved.UpdatedAt);
    }

    [Fact]
    public async Task Update_cannot_change_CreatedAt()
    {
        var time = new FakeTimeProvider(T0);
        var db = await sql.CreateDatabaseAsync(time);
        await using (var context = db.NewContext())
        {
            context.Items.Add(new TestItem { Name = "a" });
            await context.SaveChangesAsync();
        }

        time.Advance(TimeSpan.FromHours(1));
        await using (var context = db.NewContext())
        {
            var item = await context.Items.SingleAsync();
            item.CreatedAt = new DateTime(2000, 1, 1, 0, 0, 0, DateTimeKind.Utc);
            item.Name = "b";
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        Assert.Equal(T0.UtcDateTime, (await read.Items.SingleAsync()).CreatedAt);
    }

    [Fact]
    public async Task Remove_is_a_soft_delete_the_row_stays_but_is_hidden_by_default()
    {
        var time = new FakeTimeProvider(T0);
        var db = await sql.CreateDatabaseAsync(time);
        await using (var context = db.NewContext())
        {
            context.Items.Add(new TestItem { Name = "a" });
            await context.SaveChangesAsync();
        }

        time.Advance(TimeSpan.FromMinutes(5));
        await using (var context = db.NewContext())
        {
            context.Items.Remove(await context.Items.SingleAsync());
            await context.SaveChangesAsync();
        }

        await using var read = db.NewContext();
        Assert.Equal(0, await read.Items.CountAsync());
        var row = await read.Items.IgnoreQueryFilters().SingleAsync();
        Assert.True(row.IsDeleted);
        Assert.Equal(T0.AddMinutes(5).UtcDateTime, row.UpdatedAt);
    }

    [Fact]
    public async Task RowVersion_detects_two_concurrent_updates()
    {
        var db = await sql.CreateDatabaseAsync(new FakeTimeProvider(T0));
        await using (var context = db.NewContext())
        {
            context.Items.Add(new TestItem { Name = "a" });
            await context.SaveChangesAsync();
        }

        await using var first = db.NewContext();
        await using var second = db.NewContext();
        var itemFirst = await first.Items.SingleAsync();
        var itemSecond = await second.Items.SingleAsync();

        itemFirst.Name = "first";
        await first.SaveChangesAsync();

        itemSecond.Name = "second";
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => second.SaveChangesAsync());
    }
}
