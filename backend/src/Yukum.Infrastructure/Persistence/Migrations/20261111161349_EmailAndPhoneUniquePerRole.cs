using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class EmailAndPhoneUniquePerRole : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // VERİ TAŞIMA: giriş adı (UserName) eskiden e-postanın kendisiydi; artık "e-posta_Rol" (aynı e-posta iki rolde olabilsin diye).
            // Mevcut hesaplar yeni biçime çevrilir. Silinmiş (anonimleşmiş) hesapların adı "deleted-..." zaten benzersiz, dokunulmaz.
            // UserType: 1 = Shipper, 2 = Carrier, 3 = Admin. Normalleştirilmiş ad Identity gibi BÜYÜK harftir.
            migrationBuilder.Sql(@"
                UPDATE Users
                SET UserName = Email + '_' + CASE UserType WHEN 1 THEN 'Shipper' WHEN 2 THEN 'Carrier' ELSE 'Admin' END,
                    NormalizedUserName = UPPER(Email + '_' + CASE UserType WHEN 1 THEN 'Shipper' WHEN 2 THEN 'Carrier' ELSE 'Admin' END)
                WHERE Email IS NOT NULL AND UserName NOT LIKE 'deleted-%'");

            migrationBuilder.DropIndex(
                name: "EmailIndex",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Users_PhoneNumber",
                table: "Users");

            migrationBuilder.CreateIndex(
                name: "EmailIndex",
                table: "Users",
                column: "NormalizedEmail");

            migrationBuilder.CreateIndex(
                name: "IX_Users_NormalizedEmail_UserType",
                table: "Users",
                columns: new[] { "NormalizedEmail", "UserType" },
                unique: true,
                filter: "[NormalizedEmail] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Users_PhoneNumber_UserType",
                table: "Users",
                columns: new[] { "PhoneNumber", "UserType" },
                unique: true,
                filter: "[PhoneNumber] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Giriş adı eski biçime döner (e-postanın kendisi). Aynı e-posta iki rolde varsa aşağıdaki benzersiz indeks geri alınırken hata verir: bu beklenen, önce çift hesaplardan biri silinmeli.
            migrationBuilder.Sql(@"
                UPDATE Users SET UserName = Email, NormalizedUserName = UPPER(Email)
                WHERE Email IS NOT NULL AND UserName NOT LIKE 'deleted-%'");

            migrationBuilder.DropIndex(
                name: "EmailIndex",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Users_NormalizedEmail_UserType",
                table: "Users");

            migrationBuilder.DropIndex(
                name: "IX_Users_PhoneNumber_UserType",
                table: "Users");

            migrationBuilder.CreateIndex(
                name: "EmailIndex",
                table: "Users",
                column: "NormalizedEmail",
                unique: true,
                filter: "[NormalizedEmail] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Users_PhoneNumber",
                table: "Users",
                column: "PhoneNumber",
                unique: true,
                filter: "[PhoneNumber] IS NOT NULL");
        }
    }
}
