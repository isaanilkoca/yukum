using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class VehicleDetailsAndOfferVehicle : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Brand",
                table: "Vehicles",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Model",
                table: "Vehicles",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Year",
                table: "Vehicles",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "EstimatedDeliveryDate",
                table: "Offers",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "VehicleBrand",
                table: "Offers",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "VehicleId",
                table: "Offers",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "VehicleModel",
                table: "Offers",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "VehicleType",
                table: "Offers",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "VehicleYear",
                table: "Offers",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Brand",
                table: "Vehicles");

            migrationBuilder.DropColumn(
                name: "Model",
                table: "Vehicles");

            migrationBuilder.DropColumn(
                name: "Year",
                table: "Vehicles");

            migrationBuilder.DropColumn(
                name: "EstimatedDeliveryDate",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "VehicleBrand",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "VehicleId",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "VehicleModel",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "VehicleType",
                table: "Offers");

            migrationBuilder.DropColumn(
                name: "VehicleYear",
                table: "Offers");
        }
    }
}
