namespace Yukum.Application.Abstractions.Identity;

/// <summary>Kullanıcı numarasından görünen ad okur (teklif listesinde taşımacı adı için). Identity ayrıntısını Application'dan gizler.</summary>
public interface IUserDirectory
{
    /// <summary>Verilen numaraların ad soyad sözlüğünü döndürür (numara → ad).</summary>
    Task<Dictionary<Guid, string>> GetFullNamesAsync(IEnumerable<Guid> userIds, CancellationToken cancellationToken = default);
}
