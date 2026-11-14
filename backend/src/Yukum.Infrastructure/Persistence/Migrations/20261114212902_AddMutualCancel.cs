using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddMutualCancel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "CancelNote",
                table: "Offers",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CancelReason",
                table: "Offers",
                type: "nvarchar(60)",
                maxLength: 60,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "CancelReopenListing",
                table: "Offers",
                type: "bit",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancelRequestedAt",
                table: "Offers",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CancelRequestedBy",
                table: "Offers",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "MutuallyCancelled",
                table: "Offers",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CancelNote",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "CancelReason",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "CancelReopenListing",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "CancelRequestedAt",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "CancelRequestedBy",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "MutuallyCancelled",
                table: "Offers");
        }
    }
}
