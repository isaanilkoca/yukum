using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddOfferStage : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "Stage",
                table: "Offers",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Stage",
                table: "Offers");
        }
    }
}
