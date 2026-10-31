using FluentValidation;

namespace Yukum.Application.Offers;

/// <summary>Teklif kuralları (Türkçe mesajlarla).</summary>
public sealed class CreateOfferValidator : AbstractValidator<CreateOfferCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public CreateOfferValidator()
    {
        RuleFor(c => c.Amount).GreaterThan(0).WithMessage("Teklif tutarı sıfırdan büyük olmalı.");
        RuleFor(c => c.Note).MaximumLength(500).WithMessage("Not en fazla 500 karakter olabilir.");
    }
}
