using FluentValidation;
using Yukum.Application.Abstractions.Persistence;

namespace Yukum.Application.Listings;

/// <summary>İlan açma kuralları (Türkçe mesajlarla). İlçenin gerçekten o ile ait olması da denetlenir.</summary>
public sealed class CreateListingValidator : AbstractValidator<CreateListingCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public CreateListingValidator(IGeographyRepository geography)
    {
        RuleFor(c => c.Title).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("Başlık boş olamaz.")
            .Must(v => v!.Trim().Length <= 150).WithMessage("Başlık en fazla 150 karakter olabilir.");

        RuleFor(c => c.Description)
            .MaximumLength(2000).WithMessage("Açıklama en fazla 2000 karakter olabilir.");

        RuleFor(c => c.WeightKg).GreaterThan(0).WithMessage("Ağırlık sıfırdan büyük olmalı.");

        RuleFor(c => c.VehicleType).IsInEnum().WithMessage("Geçersiz araç türü.");

        RuleFor(c => c.Budget).GreaterThan(0).When(c => c.Budget.HasValue).WithMessage("Bütçe sıfırdan büyük olmalı.");

        // Geçmiş tarihe ilan açılmaz.
        RuleFor(c => c.PickupDate)
            .Must(d => d >= DateOnly.FromDateTime(DateTime.UtcNow.AddDays(-1)))
            .WithMessage("Yükleme tarihi geçmişte olamaz.");

        // Kalkış ve varış: ilçe, seçilen ile ait olmalı (il yoksa ya da ilçe başka ilin ise reddedilir).
        RuleFor(c => c).MustAsync(async (c, ct) =>
                (await geography.ListDistrictsAsync(c.FromCityId, ct)).Any(d => d.Id == c.FromDistrictId))
            .WithName("FromDistrictId").WithMessage("Kalkış ilçesi seçilen ile ait değil.");

        RuleFor(c => c).MustAsync(async (c, ct) =>
                (await geography.ListDistrictsAsync(c.ToCityId, ct)).Any(d => d.Id == c.ToDistrictId))
            .WithName("ToDistrictId").WithMessage("Varış ilçesi seçilen ile ait değil.");
    }
}
