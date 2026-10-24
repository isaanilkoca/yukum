using NSubstitute;
using Yukum.Application.Abstractions.Persistence;
using Yukum.UnitTests.Support;

namespace Yukum.UnitTests.Application;

// Veritabanı YOK: repository ve unit of work sahte. İş kuralı kodu EF'i bilmediği için bu mümkün.
public class RenameSampleItemHandlerTests
{
    private readonly IRepository<SampleItem> _items = Substitute.For<IRepository<SampleItem>>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();

    [Fact]
    public async Task Renames_the_item_and_saves_once_when_it_exists()
    {
        var item = new SampleItem { Name = "eski" };
        var id = Guid.NewGuid();
        _items.GetByIdAsync(id, Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns(item);

        var result = await new RenameSampleItemHandler(_items, _unitOfWork).HandleAsync(new RenameSampleItem(id, "yeni"));

        Assert.True(result);
        Assert.Equal("yeni", item.Name);
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Returns_false_and_saves_nothing_when_the_item_does_not_exist()
    {
        _items.GetByIdAsync(Arg.Any<Guid>(), Arg.Any<bool>(), Arg.Any<CancellationToken>()).Returns((SampleItem?)null);

        var result = await new RenameSampleItemHandler(_items, _unitOfWork).HandleAsync(new RenameSampleItem(Guid.NewGuid(), "yeni"));

        Assert.False(result);
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Query_handler_reads_without_tracking()
    {
        var id = Guid.NewGuid();
        _items.GetByIdAsync(id, true, Arg.Any<CancellationToken>()).Returns(new SampleItem { Name = "ad" });

        var name = await new GetSampleItemNameHandler(_items).HandleAsync(new GetSampleItemName(id));

        Assert.Equal("ad", name);
        await _items.Received(1).GetByIdAsync(id, true, Arg.Any<CancellationToken>());
    }
}
