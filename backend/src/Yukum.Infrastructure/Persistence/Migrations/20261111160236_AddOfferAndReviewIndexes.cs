using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddOfferAndReviewIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Reviews_ShipperId",
                table: "Reviews",
                column: "ShipperId");

            migrationBuilder.CreateIndex(
                name: "IX_Offers_CarrierId_Status",
                table: "Offers",
                columns: new[] { "CarrierId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_Offers_Status_DecidedAt",
                table: "Offers",
                columns: new[] { "Status", "DecidedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Reviews_ShipperId",
                table: "Reviews");

            migrationBuilder.DropIndex(
                name: "IX_Offers_CarrierId_Status",
                table: "Offers");

            migrationBuilder.DropIndex(
                name: "IX_Offers_Status_DecidedAt",
                table: "Offers");
        }
    }
}
