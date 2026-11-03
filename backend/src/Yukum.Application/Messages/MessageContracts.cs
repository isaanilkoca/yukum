namespace Yukum.Application.Messages;

/// <summary>İstemcinin gönderdiği mesaj (teklif numarası adresten, gönderen jetondan gelir).</summary>
public sealed record SendMessageRequest(string? Text);

/// <summary>Komut: sohbete mesaj yaz.</summary>
public sealed record SendMessageCommand(Guid OfferId, Guid UserId, string? Text);

/// <summary>Sorgu: bir teklifin sohbet mesajları.</summary>
public sealed record GetMessagesQuery(Guid OfferId, Guid UserId);

/// <summary>İstemciye giden mesaj. IsMine: mesajı isteği yapan kişi mi yazdı (iOS balonu sağa/sola koymak için).</summary>
public sealed record MessageDto(Guid Id, string Text, DateTime CreatedAt, bool IsMine);

/// <summary>Komut: kullanıcı sohbeti YALNIZ KENDİ görünümünden siler (karşı tarafın sohbeti durur).</summary>
public sealed record ClearChatCommand(Guid OfferId, Guid UserId);
