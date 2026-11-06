namespace Yukum.Domain.Listings;

/// <summary>Kabul edilmiş işin aşaması. Yalnız ileri gider, aşama atlanamaz: NotStarted → PickedUp → InTransit → Delivered. Aşamayı Taşımacı ilerletir.</summary>
public enum JobStage
{
    /// <summary>Kabul edildi, yük henüz alınmadı (varsayılan; bekleyen tekliflerde de bu değer durur, anlamsızdır).</summary>
    NotStarted = 0,

    /// <summary>Yük alındı.</summary>
    PickedUp = 1,

    /// <summary>Yolda.</summary>
    InTransit = 2,

    /// <summary>Teslim edildi. Bundan sonra iş tamamlanabilir ("İşi bitir") ve puan verilebilir.</summary>
    Delivered = 3
}
