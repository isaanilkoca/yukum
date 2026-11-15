using Yukum.Domain.Accounts;

namespace Yukum.Application.Accounts;

// ┌─ GÜVENLİK: ENGELLE + ŞİKÂYET ET (15 Kasım, Apple kuralı 1.2: kullanıcılar arası içerik varsa ikisi de şart) ─────────────
// │ BAĞLANTI HARİTASI
// │   iOS (sohbet / profil / ilan detayı "⋯" menüsü) → Api/Controllers/SafetyController
// │     PUT    /api/v1/users/{userId}/block    → BlockUserHandler     → IBlockRepository.BlockAsync
// │     DELETE /api/v1/users/{userId}/block    → BlockUserHandler     → IBlockRepository.UnblockAsync
// │     GET    /api/v1/account/blocks          → GetBlockedUsersHandler (+ IUserDirectory: ad)
// │     POST   /api/v1/users/{userId}/report   → ReportUserHandler    → IRepository<UserReport>
// │ ENGELİN ETKİSİ (iki yönlü: hangisi engellemiş olursa olsun)
// │   SendMessageHandler 409 · CreateOfferHandler 409 · ListingSearchRepository (ilan listeden düşer) · GetFavoriteListingsHandler
// │ NEDEN devam eden iş iptal edilmez: tek taraflı iptal karşı tarafı yarı yolda bırakır → karşılıklı iptal akışı (CancelRequestHandlers) kullanılır.
// └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

/// <summary>Komut: kullanıcı birini engeller (IsBlocked=true) ya da engeli kaldırır (false). İkisi de idempotent.</summary>
public sealed record BlockUserCommand(Guid UserId, Guid TargetId, bool IsBlocked);

/// <summary>Sorgu: kullanıcının engellediği kişiler.</summary>
public sealed record GetBlockedUsersQuery(Guid UserId);

/// <summary>Engellenen kişi satırı (Profil → Engellediklerim).</summary>
public sealed record BlockedUserDto(Guid UserId, string FullName, DateTime BlockedAt);

/// <summary>Şikâyet isteğinin gövdesi. Reason zorunlu; ilan/teklif numarası şikâyetin nereden geldiğini gösterir (isteğe bağlı).</summary>
public sealed record ReportUserRequest(ReportReason? Reason, string? Note, Guid? ListingId, Guid? OfferId);

/// <summary>Komut: kullanıcı birini şikâyet eder.</summary>
public sealed record ReportUserCommand(Guid ReporterId, Guid ReportedUserId, ReportReason? Reason, string? Note, Guid? ListingId, Guid? OfferId);
