using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Infrastructure;

/// <summary>Infrastructure katmanının (veritabanı, repository) servislerini uygulamaya kaydeder.</summary>
public static class DependencyInjection
{
    /// <summary>
    /// Veritabanı bağlantısını (SQL Server), saat servisini ve repository'leri kaydeder. <c>Program.cs</c> bunu çağırır.
    /// Bağlantı dizesi <c>ConnectionStrings:DefaultConnection</c> anahtarından okunur (user-secrets / ortam değişkeni).
    /// </summary>
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

        return services.AddRepositories();
    }

    /// <summary>
    /// Yalnız <see cref="IRepository{T}"/> ve <see cref="IUnitOfWork"/> kayıtları. Ayrı metot olmasının sebebi:
    /// testler kendi DbContext'iyle aynı kayıtları kullanabilsin.
    /// </summary>
    public static IServiceCollection AddRepositories(this IServiceCollection services)
    {
        services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        return services;
    }
}
