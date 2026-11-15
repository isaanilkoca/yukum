using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class MutualCancelReoffer : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Offers_ListingId_CarrierId",
                table: "Offers");

            migrationBuilder.CreateIndex(
                name: "IX_Offers_ListingId_CarrierId",
                table: "Offers",
                columns: new[] { "ListingId", "CarrierId" },
                unique: true,
                filter: "[MutuallyCancelled] = 0");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Offers_ListingId_CarrierId",
                table: "Offers");

            migrationBuilder.CreateIndex(
                name: "IX_Offers_ListingId_CarrierId",
                table: "Offers",
                columns: new[] { "ListingId", "CarrierId" },
                unique: true);
        }
    }
}
