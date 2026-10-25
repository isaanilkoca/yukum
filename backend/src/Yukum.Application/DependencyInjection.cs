using System.Reflection;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Yukum.Application.Abstractions.Messaging;

namespace Yukum.Application;

/// <summary>Application katmanının servislerini (handler'ları) uygulamaya kaydeder.</summary>
public static class DependencyInjection
{
    /// <summary>
    /// Application projesindeki tüm handler'ları ve doğrulama kurallarını (FluentValidation) bulup kaydeder.
    /// <c>Program.cs</c> bunu çağırır.
    /// </summary>
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        // Doğrulayıcılar scoped: il listesi gibi scoped servislere (repository) bağlanırlar.
        // FluentValidation: bu projedeki tüm doğrulayıcı sınıfları (…Validator) bulup kaydeder.
        services.AddValidatorsFromAssembly(typeof(DependencyInjection).Assembly, ServiceLifetime.Scoped);
        // Handler'ları kaydet. Yeni handler yazınca başka yere dokunmak gerekmez, otomatik bulunur.
        return services.AddHandlersFromAssembly(typeof(DependencyInjection).Assembly);
    }

    /// <summary>
    /// Verilen derlemedeki üst düzey, soyut olmayan handler sınıflarını bulup kaydeder.
    /// Yeni handler yazınca başka hiçbir yere dokunmak gerekmez.
    /// </summary>
    public static IServiceCollection AddHandlersFromAssembly(this IServiceCollection services, Assembly assembly) =>
        // Projedeki tüm sınıflar taranır (iç içe tanımlı olanlar hariç).
        services.AddHandlers(assembly.GetTypes().Where(t => !t.IsNested));

    /// <summary>
    /// Verilen sınıfların handler arayüzlerini kaydeder. Aynı komut için iki farklı handler bulunursa
    /// uygulama açılırken <see cref="InvalidOperationException"/> fırlatır (sessiz yanlışlığı önler).
    /// </summary>
    public static IServiceCollection AddHandlers(this IServiceCollection services, IEnumerable<Type> types)
    {
        // Her sınıf için: gerçek (soyut olmayan) bir sınıf mı?
        foreach (var type in types.Where(t => t is { IsClass: true, IsAbstract: false, IsGenericTypeDefinition: false }))
        {
            // Sınıfın uyguladığı arayüzler arasından ICommandHandler / IQueryHandler olanları bul.
            foreach (var handlerInterface in type.GetInterfaces().Where(IsHandlerInterface))
            {
                // Bu arayüz (örn. ICommandHandler<LoginCommand, LoginResponse>) daha önce kaydedilmiş mi?
                var existing = services.FirstOrDefault(d => d.ServiceType == handlerInterface);
                if (existing is null)
                    // Kaydet: biri bu arayüzü isterse şu sınıfı ver. 'Scoped' = her HTTP isteği için yeni bir örnek.
                    services.AddScoped(handlerInterface, type);
                else if (existing.ImplementationType != type)
                    // Aynı komut için iki handler varsa uygulama AÇILIRKEN hata verir (sessiz yanlışlığı önler).
                    throw new InvalidOperationException(
                        $"{handlerInterface.GenericTypeArguments[0].Name} için iki handler var: " +
                        $"{existing.ImplementationType?.Name} ve {type.Name}. Her komut/sorgunun tek handler'ı olmalı.");
            }
        }

        return services;
    }

    // Tür ICommandHandler<,> ya da IQueryHandler<,> ailesinden mi?
    private static bool IsHandlerInterface(Type type) =>
        type.IsGenericType &&
        (type.GetGenericTypeDefinition() == typeof(ICommandHandler<,>) ||
         type.GetGenericTypeDefinition() == typeof(IQueryHandler<,>));
}
