using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services)
    {
        services.AddSingleton(TimeProvider.System);

        // Bağlantı dizesi DbContext ilk kullanıldığında okunur (user-secrets / ortam değişkeni / test ayarı).
        services.AddDbContext<AppDbContext>((provider, options) =>
        {
            var connectionString = provider.GetRequiredService<IConfiguration>().GetConnectionString("DefaultConnection");
            if (string.IsNullOrWhiteSpace(connectionString))
                throw new InvalidOperationException(
                    "ConnectionStrings:DefaultConnection tanımlı değil. README'deki user-secrets adımını uygulayın.");

            options.UseSqlServer(connectionString);
        });

        return services;
    }
}
