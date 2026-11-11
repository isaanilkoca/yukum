using FluentValidation;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Application.Notifications;

/// <summary>Cihaz jetonu kuralları. APNs jetonu onaltılık yazıdır (bugün 64 karakter; Apple uzayabileceğini söylediği için üst sınır geniş).</summary>
public sealed class RegisterDeviceTokenValidator : AbstractValidator<RegisterDeviceTokenCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public RegisterDeviceTokenValidator()
    {
        RuleFor(c => c.Token).NotEmpty().WithMessage("Cihaz jetonu gerekli.")
            .Matches("^[0-9a-fA-F]{64,200}$").WithMessage("Cihaz jetonu geçersiz.");
        RuleFor(c => c.DeviceId).NotEmpty().WithMessage("Cihaz kimliği gerekli.")
            .MaximumLength(100).WithMessage("Cihaz kimliği en fazla 100 karakter olabilir.");
    }
}

/// <summary>Telefonun push adresini giriş yapmış kullanıcıya kaydeder.</summary>
public sealed class RegisterDeviceTokenHandler(IValidator<RegisterDeviceTokenCommand> validator, IDeviceTokenRepository devices)
    : ICommandHandler<RegisterDeviceTokenCommand, bool>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | NotificationsController çağırır: jetonu doğrular ve kaydeder (aynı jeton tekrar gelirse günceller)
    /// <summary>Geçersiz jeton/cihaz kimliği 400.</summary>
    public async Task<bool> HandleAsync(RegisterDeviceTokenCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        await devices.UpsertAsync(command.UserId, command.DeviceId!.Trim(), command.Token!.ToLowerInvariant(), command.Sandbox, cancellationToken);
        return true;
    }
}

/// <summary>Çıkışta bu cihazın push adresini siler: çıkış yapan kullanıcıya o telefonda bildirim gitmez.</summary>
public sealed class RemoveDeviceTokenHandler(IDeviceTokenRepository devices) : ICommandHandler<RemoveDeviceTokenCommand, bool>
{
    /// <summary>Kayıt yoksa da başarılı (idempotent).</summary>
    public async Task<bool> HandleAsync(RemoveDeviceTokenCommand command, CancellationToken cancellationToken = default)
    {
        if (!string.IsNullOrWhiteSpace(command.DeviceId))
            await devices.RemoveForDeviceAsync(command.UserId, command.DeviceId.Trim(), cancellationToken);
        return true;
    }
}
