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
        // Testler geliştiricinin user-secrets'ındaki gerçek veritabanına bağımlı olmasın: varsayılan boş.
        // Veritabanı isteyen testler WithWebHostBuilder(...UseSetting(...)) ile kendi bağlantısını verir.
        builder.UseSetting("ConnectionStrings:DefaultConnection", "");

        // JWT: testler geliştiricinin user-secrets'ındaki gerçek anahtara bağımlı olmasın; kendi sahte ayarlarını kullanır.
        builder.UseSetting("Jwt:Issuer", TestJwt.Issuer);
        builder.UseSetting("Jwt:Audience", TestJwt.Audience);
        builder.UseSetting("Jwt:SigningKey", TestJwt.Key);
        builder.UseSetting("Jwt:AccessTokenMinutes", "15");

        builder.ConfigureTestServices(services =>
            services.AddControllers().AddApplicationPart(typeof(YukumApiFactory).Assembly));
    }
}
