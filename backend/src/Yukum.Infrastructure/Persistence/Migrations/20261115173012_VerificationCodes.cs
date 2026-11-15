using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class VerificationCodes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // 15 Kasım: e-posta doğrulama zorunlu oldu. Bu tarihten ÖNCE açılmış hesaplar doğrulanmış sayılır
            //   (yoksa mevcut kullanıcılar bir anda giriş yapamaz). Yeni kayıtlar EmailConfirmed = 0 başlar, kodla doğrulanır.
            migrationBuilder.Sql("UPDATE Users SET EmailConfirmed = 1 WHERE EmailConfirmed = 0;");

            migrationBuilder.CreateTable(
                name: "VerificationCodes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Purpose = table.Column<int>(type: "int", nullable: false),
                    CodeHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Attempts = table.Column<int>(type: "int", nullable: false),
                    UsedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsDeleted = table.Column<bool>(type: "bit", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VerificationCodes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_VerificationCodes_UserId_Purpose",
                table: "VerificationCodes",
                columns: new[] { "UserId", "Purpose" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "VerificationCodes");
        }
    }
}
