using System.Reflection;
using Microsoft.Extensions.DependencyInjection;
using Yukum.Application.Abstractions.Messaging;

namespace Yukum.Application;

/// <summary>Application katmanının servislerini (handler'ları) uygulamaya kaydeder.</summary>
public static class DependencyInjection
{
    /// <summary>Application projesindeki tüm handler'ları bulup kaydeder. <c>Program.cs</c> bunu çağırır.</summary>
    public static IServiceCollection AddApplication(this IServiceCollection services) =>
        services.AddHandlersFromAssembly(typeof(DependencyInjection).Assembly);

    /// <summary>
    /// Verilen derlemedeki üst düzey, soyut olmayan handler sınıflarını bulup kaydeder.
    /// Yeni handler yazınca başka hiçbir yere dokunmak gerekmez.
    /// </summary>
    public static IServiceCollection AddHandlersFromAssembly(this IServiceCollection services, Assembly assembly) =>
        services.AddHandlers(assembly.GetTypes().Where(t => !t.IsNested));

    /// <summary>
    /// Verilen sınıfların handler arayüzlerini kaydeder. Aynı komut için iki farklı handler bulunursa
    /// uygulama açılırken <see cref="InvalidOperationException"/> fırlatır (sessiz yanlışlığı önler).
    /// </summary>
    public static IServiceCollection AddHandlers(this IServiceCollection services, IEnumerable<Type> types)
    {
        foreach (var type in types.Where(t => t is { IsClass: true, IsAbstract: false, IsGenericTypeDefinition: false }))
        {
            foreach (var handlerInterface in type.GetInterfaces().Where(IsHandlerInterface))
            {
                var existing = services.FirstOrDefault(d => d.ServiceType == handlerInterface);
                if (existing is null)
                    services.AddScoped(handlerInterface, type);
                else if (existing.ImplementationType != type)
                    throw new InvalidOperationException(
                        $"{handlerInterface.GenericTypeArguments[0].Name} için iki handler var: " +
                        $"{existing.ImplementationType?.Name} ve {type.Name}. Her komut/sorgunun tek handler'ı olmalı.");
            }
        }

        return services;
    }

    private static bool IsHandlerInterface(Type type) =>
        type.IsGenericType &&
        (type.GetGenericTypeDefinition() == typeof(ICommandHandler<,>) ||
         type.GetGenericTypeDefinition() == typeof(IQueryHandler<,>));
}
