using FluentValidation;
using FluentValidation.Results;
using Yukum.Application.Abstractions.Identity;
using Yukum.Application.Abstractions.Messaging;
using Yukum.Application.Abstractions.Persistence;
using Yukum.Application.Common;
using Yukum.Domain.Accounts;

namespace Yukum.Application.Accounts;

/// <summary>Engeller / engeli kaldırır. Kendini engellemek 400, olmayan kullanıcı 404.</summary>
public sealed class BlockUserHandler(IBlockRepository blocks, IUserDirectory users) : ICommandHandler<BlockUserCommand, bool>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | SafetyController çağırır: hedef var mı bakar, engel satırını ekler/siler
    /// <summary>Kendini hedeflerse ValidationException (400), hedef yoksa NotFoundException (404).</summary>
    public async Task<bool> HandleAsync(BlockUserCommand command, CancellationToken cancellationToken = default)
    {
        if (command.UserId == command.TargetId)
            throw new ValidationException([new ValidationFailure("userId", "Kendini engelleyemezsin.")]);
        if (command.IsBlocked)
        {
            // Kaldırırken varlık bakılmaz: silinmiş hesabın engeli de listeden kaldırılabilsin.
            if (!(await users.GetFullNamesAsync([command.TargetId], cancellationToken)).ContainsKey(command.TargetId))
                throw new NotFoundException("Kullanıcı bulunamadı.");
            await blocks.BlockAsync(command.UserId, command.TargetId, cancellationToken);
        }
        else await blocks.UnblockAsync(command.UserId, command.TargetId, cancellationToken);
        return true;
    }
}

/// <summary>Kullanıcının engellediği kişiler (ad ile), en son engellenen üstte.</summary>
public sealed class GetBlockedUsersHandler(IBlockRepository blocks, IUserDirectory users) : IQueryHandler<GetBlockedUsersQuery, IReadOnlyList<BlockedUserDto>>
{
    /// <summary>Adı bulunamayan (çok eski/silinmiş) kişi "Silinmiş Kullanıcı" görünür ki engel yine kaldırılabilsin.</summary>
    public async Task<IReadOnlyList<BlockedUserDto>> HandleAsync(GetBlockedUsersQuery query, CancellationToken cancellationToken = default)
    {
        var list = await blocks.ListBlockedAsync(query.UserId, cancellationToken);
        var names = await users.GetFullNamesAsync(list.Select(b => b.UserId), cancellationToken);
        return list.Select(b => new BlockedUserDto(b.UserId, names.GetValueOrDefault(b.UserId, "Silinmiş Kullanıcı"), b.BlockedAt)).ToList();
    }
}

/// <summary>Şikâyet kuralları: neden zorunlu ve listeden olmalı, not en çok 500 karakter.</summary>
public sealed class ReportUserValidator : AbstractValidator<ReportUserCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public ReportUserValidator()
    {
        RuleFor(c => c.Reason).NotNull().WithMessage("Şikâyet nedenini seç.")
            .IsInEnum().WithMessage("Geçersiz şikâyet nedeni.");
        RuleFor(c => c.Note).MaximumLength(500).WithMessage("Not en fazla 500 karakter olabilir.");
    }
}

/// <summary>Şikâyeti kaydeder. Aynı kişiyi 24 saat içinde ikinci kez şikâyet etmek yeni satır açmaz (sessizce başarılı: spam'i keser, kullanıcıyı da kızdırmaz).</summary>
public sealed class ReportUserHandler(
    IValidator<ReportUserCommand> validator,
    IRepository<UserReport> reports,
    IUserDirectory users,
    IUnitOfWork unitOfWork,
    TimeProvider time) : ICommandHandler<ReportUserCommand, bool>
{
    // FONKSİYON ROLÜ: API'NİN İŞ MANTIĞI | SafetyController çağırır: doğrular, hedef var mı bakar, "UserReports" tablosuna yazar
    /// <summary>Doğrulama 400, kendini şikâyet 400, hedef yoksa 404.</summary>
    public async Task<bool> HandleAsync(ReportUserCommand command, CancellationToken cancellationToken = default)
    {
        await validator.ValidateAndThrowAsync(command, cancellationToken);
        if (command.ReporterId == command.ReportedUserId)
            throw new ValidationException([new ValidationFailure("userId", "Kendini şikâyet edemezsin.")]);
        if (!(await users.GetFullNamesAsync([command.ReportedUserId], cancellationToken)).ContainsKey(command.ReportedUserId))
            throw new NotFoundException("Kullanıcı bulunamadı.");

        var since = time.GetUtcNow().UtcDateTime.AddHours(-24);
        if (await reports.AnyAsync(r => r.ReporterId == command.ReporterId && r.ReportedUserId == command.ReportedUserId && r.CreatedAt >= since, cancellationToken))
            return true; // son 24 saatte zaten şikâyet etmiş

        reports.Add(new UserReport
        {
            ReporterId = command.ReporterId,
            ReportedUserId = command.ReportedUserId,
            Reason = command.Reason!.Value,
            Note = string.IsNullOrWhiteSpace(command.Note) ? null : command.Note.Trim(),
            ListingId = command.ListingId,
            OfferId = command.OfferId
        });
        await unitOfWork.SaveChangesAsync(cancellationToken);
        return true;
    }
}
