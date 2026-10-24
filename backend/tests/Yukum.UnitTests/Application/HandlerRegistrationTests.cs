using Microsoft.Extensions.DependencyInjection;
using Yukum.Application;
using Yukum.Application.Abstractions.Messaging;
using Yukum.UnitTests.Support;

namespace Yukum.UnitTests.Application;

public class HandlerRegistrationTests
{
    // Çakışma testi için: RenameSampleItem'a ikinci handler. İç içe tanımlı olduğu için assembly taramasında görünmez.
    private sealed class DuplicateRenameHandler : ICommandHandler<RenameSampleItem, bool>
    {
        public Task<bool> HandleAsync(RenameSampleItem command, CancellationToken cancellationToken = default) => Task.FromResult(false);
    }

    private static ServiceCollection ScanTestAssembly()
    {
        var services = new ServiceCollection();
        services.AddHandlersFromAssembly(typeof(SampleItem).Assembly);
        return services;
    }

    [Fact]
    public void Scanning_registers_command_and_query_handlers_as_scoped()
    {
        var services = ScanTestAssembly();

        var command = Assert.Single(services, d => d.ServiceType == typeof(ICommandHandler<RenameSampleItem, bool>));
        var query = Assert.Single(services, d => d.ServiceType == typeof(IQueryHandler<GetSampleItemName, string?>));
        Assert.Equal(typeof(RenameSampleItemHandler), command.ImplementationType);
        Assert.Equal(typeof(GetSampleItemNameHandler), query.ImplementationType);
        Assert.Equal(ServiceLifetime.Scoped, command.Lifetime);
        Assert.Equal(ServiceLifetime.Scoped, query.Lifetime);
    }

    [Fact]
    public void Scanning_does_not_register_abstract_or_nested_classes()
    {
        var implementations = ScanTestAssembly().Select(d => d.ImplementationType).ToList();

        Assert.DoesNotContain(typeof(AbstractSampleHandler), implementations);
        Assert.DoesNotContain(typeof(DuplicateRenameHandler), implementations);
    }

    [Fact]
    public void Scanning_twice_does_not_duplicate_registrations()
    {
        var services = ScanTestAssembly();
        services.AddHandlersFromAssembly(typeof(SampleItem).Assembly);

        Assert.Single(services, d => d.ServiceType == typeof(ICommandHandler<RenameSampleItem, bool>));
    }

    [Fact]
    public void Two_different_handlers_for_the_same_command_fail_loudly()
    {
        var services = new ServiceCollection();

        var error = Assert.Throws<InvalidOperationException>(() =>
            services.AddHandlers([typeof(RenameSampleItemHandler), typeof(DuplicateRenameHandler)]));

        Assert.Contains("RenameSampleItem", error.Message);
    }

    [Fact]
    public void AddApplication_runs_on_the_real_application_assembly()
    {
        // Gerçek Application projesinde henüz handler yok; kaydın hatasız çalıştığını doğrular.
        var services = new ServiceCollection();
        services.AddApplication();
        Assert.NotNull(services);
    }
}
