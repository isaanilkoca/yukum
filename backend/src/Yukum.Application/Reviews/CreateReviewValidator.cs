using FluentValidation;

namespace Yukum.Application.Reviews;

/// <summary>Puan kuralları (Türkçe mesajlarla).</summary>
public sealed class CreateReviewValidator : AbstractValidator<CreateReviewCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public CreateReviewValidator()
    {
        RuleFor(c => c.Rating).InclusiveBetween(1, 5).WithMessage("Puan 1 ile 5 arasında olmalı.");
        RuleFor(c => c.Comment).MaximumLength(500).WithMessage("Yorum en fazla 500 karakter olabilir.");
    }
}
