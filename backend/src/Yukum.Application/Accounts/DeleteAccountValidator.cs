using FluentValidation;

namespace Yukum.Application.Accounts;

/// <summary>Silme onayı kuralı: şifre boş olamaz.</summary>
public sealed class DeleteAccountValidator : AbstractValidator<DeleteAccountCommand>
{
    /// <summary>Kuralı kurar.</summary>
    public DeleteAccountValidator()
    {
        RuleFor(c => c.Password).NotEmpty().WithMessage("Hesabı silmek için şifreni gir.");
    }
}
