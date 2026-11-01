using FluentValidation;

namespace Yukum.Application.Messages;

/// <summary>Mesaj kuralları (Türkçe mesajlarla).</summary>
public sealed class SendMessageValidator : AbstractValidator<SendMessageCommand>
{
    /// <summary>Kuralları kurar.</summary>
    public SendMessageValidator()
    {
        RuleFor(c => c.Text).Cascade(CascadeMode.Stop)
            .NotEmpty().WithMessage("Mesaj boş olamaz.")
            .Must(t => t!.Trim().Length <= 1000).WithMessage("Mesaj en fazla 1000 karakter olabilir.");
    }
}
