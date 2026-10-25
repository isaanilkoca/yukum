using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Accounts;
using Yukum.Infrastructure.Identity;
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

        services.AddRepositories();
        return services.AddAccounts();
    }

    /// <summary>
    /// Yalnız <see cref="IRepository{T}"/> ve <see cref="IUnitOfWork"/> kayıtları. Ayrı metot olmasının sebebi:
    /// testler kendi DbContext'iyle aynı kayıtları kullanabilsin.
    /// </summary>
    public static IServiceCollection AddRepositories(this IServiceCollection services)
    {
        services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
        services.AddScoped<IUnitOfWork, UnitOfWork>();

        // İl/ilçe okuması (özel repository) ve onun önbelleği.
        services.AddMemoryCache();
        services.AddScoped<IGeographyRepository, GeographyRepository>();
        return services;
    }

    /// <summary>
    /// Kimlik servislerini kaydeder: kullanıcı yöneticisi (<see cref="UserManager{TUser}"/>), şifre hash'leme (PBKDF2),
    /// şifre ve kilit kuralları, rol desteği ve hesap oluşturma servisi. Ayrı metot olmasının sebebi testlerin kendi
    /// DbContext'iyle aynı kayıtları kullanabilmesi.
    /// </summary>
    public static IServiceCollection AddAccounts(this IServiceCollection services)
    {
        services.AddIdentityCore<AppUser>(options =>
            {
                // Şifre kuralı (karar K-017) tek yerde, PasswordPolicy'dedir; Identity'ye aşağıda PasswordPolicyValidator ile
                // bağlanır. Identity'nin kendi büyük/küçük harf kontrolleri yalnız ASCII baktığı için kapalıdır.
                options.Password.RequiredLength = PasswordPolicy.MinLength;
                options.Password.RequireUppercase = false;
                options.Password.RequireLowercase = false;
                options.Password.RequireDigit = false;
                options.Password.RequireNonAlphanumeric = false;

                // Her e-posta tek hesap. Giriş adı e-postanın kendisidir.
                options.User.RequireUniqueEmail = true;

                // 5 yanlış denemede 15 dakika kilit (rapor 6.2; giriş uçları D3'te bunu kullanır).
                options.Lockout.AllowedForNewUsers = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddPasswordValidator<PasswordPolicyValidator>()
            .AddEntityFrameworkStores<AppDbContext>();

        services.AddScoped<IAccountService, AccountService>();
        return services;
    }
}
