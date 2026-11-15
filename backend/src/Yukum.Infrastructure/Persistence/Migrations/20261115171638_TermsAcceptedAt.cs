using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Yukum.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class TermsAcceptedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "TermsAcceptedAt",
                table: "Users",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TermsAcceptedAt",
                table: "Users");
        }
    }
}
