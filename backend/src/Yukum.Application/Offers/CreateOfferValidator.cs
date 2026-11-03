using FluentValidation;

namespace Yukum.Application.Offers;

/// <summary>Teklif kuralları (Türkçe mesajlarla).</summary>
public sealed class CreateOfferValidator : AbstractValidator<CreateOfferCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public CreateOfferValidator()
    {
        RuleFor(c => c.Amount).GreaterThan(0).WithMessage("Teklif tutarı sıfırdan büyük olmalı.")
            // Üst sınır: DB sütunu decimal(12,2); aşan sayı 500 verirdi, 400 ile reddedilir.
            .LessThanOrEqualTo(100_000_000m).WithMessage("Teklif tutarı en fazla 100.000.000 ₺ olabilir.");
        RuleFor(c => c.Note).MaximumLength(500).WithMessage("Not en fazla 500 karakter olabilir.");
    }
}
