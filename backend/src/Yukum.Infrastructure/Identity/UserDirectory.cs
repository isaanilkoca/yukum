using Microsoft.EntityFrameworkCore;
using Yukum.Application.Abstractions.Identity;
using Yukum.Infrastructure.Persistence;

namespace Yukum.Infrastructure.Identity;

/// <summary><see cref="IUserDirectory"/> gerçekleştirmesi: Users tablosundan yalnız ad soyad okur.</summary>
public class UserDirectory(AppDbContext context) : IUserDirectory
{
    /// <inheritdoc />
    public async Task<Dictionary<Guid, string>> GetFullNamesAsync(IEnumerable<Guid> userIds, CancellationToken cancellationToken = default)
    {
        var ids = userIds.Distinct().ToList();
        // SQL: WHERE Id IN (...) | yalnız Id ve FullName çekilir
        return await context.Users.AsNoTracking().Where(u => ids.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, u => u.FullName, cancellationToken);
    }
}
