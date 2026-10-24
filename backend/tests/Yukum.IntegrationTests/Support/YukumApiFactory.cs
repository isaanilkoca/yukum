using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;

namespace Yukum.IntegrationTests.Support;

// Gerçek API'yi bellekte ayağa kaldırır; ek olarak yalnız test projesindeki örnek uçları (TestEndpointsController) ekler.
public sealed class YukumApiFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
            services.AddControllers().AddApplicationPart(typeof(YukumApiFactory).Assembly));
    }
}
