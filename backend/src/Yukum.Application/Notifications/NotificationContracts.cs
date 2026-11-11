using Yukum.Domain.Notifications;

namespace Yukum.Application.Notifications;

/// <summary>Sorgu: kullanıcının bildirim listesi (sayfalı).</summary>
public sealed record GetNotificationsQuery(Guid UserId, int Page, int PageSize);

/// <summary>Sorgu: okunmamış bildirim sayısı.</summary>
public sealed record GetUnreadNotificationCountQuery(Guid UserId);

/// <summary>Komut: tek bildirimi okundu yap.</summary>
public sealed record MarkNotificationReadCommand(Guid UserId, Guid NotificationId);

/// <summary>Komut: hepsini okundu yap.</summary>
public sealed record MarkAllNotificationsReadCommand(Guid UserId);

/// <summary>Listedeki bir bildirim. IsRead = ReadAt dolu.</summary>
public sealed record NotificationDto(Guid Id, NotificationType Type, string Title, string Body, Guid? ListingId, Guid? OfferId, bool IsRead, DateTime CreatedAt);

/// <summary>Okunmamış bildirim sayısı.</summary>
public sealed record UnreadNotificationCountDto(int Count);
