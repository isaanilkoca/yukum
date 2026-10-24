using System.Reflection;
using Microsoft.Extensions.DependencyInjection;
using Yukum.Application.Abstractions.Messaging;

namespace Yukum.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services) =>
        services.AddHandlersFromAssembly(typeof(DependencyInjection).Assembly);

    // Assembly'deki üst düzey, soyut olmayan handler sınıflarını bulup kaydeder (yeni handler yazınca başka yere dokunulmaz).
    public static IServiceCollection AddHandlersFromAssembly(this IServiceCollection services, Assembly assembly) =>
        services.AddHandlers(assembly.GetTypes().Where(t => !t.IsNested));

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
