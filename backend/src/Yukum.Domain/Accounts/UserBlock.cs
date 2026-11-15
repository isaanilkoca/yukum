using Yukum.Domain.Common;

namespace Yukum.Domain.Accounts;

/// <summary>
/// Bir kullanıcının başka bir kullanıcıyı engellemesi (15 Kasım, Apple 1.2: kullanıcılar arası içerikte "engelle" şart).
/// (Engelleyen, engellenen) çifti benzersizdir. Engel İKİ YÖNLÜ işler: hangisi engellemiş olursa olsun ikisi
/// birbirine mesaj yazamaz, Taşımacı o Yük Veren'in ilanlarını görmez ve teklif veremez.
/// </summary>
// BAĞLANTI HARİTASI: SafetyController (PUT/DELETE /users/{id}/block) → BlockUserHandler → IBlockRepository → "UserBlocks" tablosu
//   Okuyanlar: SendMessageHandler (409), CreateOfferHandler (409), ListingSearchRepository (ilan listesinden düşer), GetFavoriteListingsHandler
public class UserBlock : BaseEntity
{
    /// <summary>Engelleyen kullanıcı.</summary>
    public Guid BlockerId { get; set; }

    /// <summary>Engellenen kullanıcı.</summary>
    public Guid BlockedId { get; set; }
}
