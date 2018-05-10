using System;
using System.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using System.Linq;

namespace MapStatsWeb.Models
{
    public partial class MapstatsContext : DbContext
    {
        public virtual DbSet<MapstatsData> MapstatsData { get; set; }
        public virtual DbSet<MapstatsMaps> MapstatsMaps { get; set; }
        public virtual DbSet<MapstatsServers> MapstatsServers { get; set; }

        public MapstatsContext(DbContextOptions<MapstatsContext> options)
            : base(options)
        { }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<MapstatsData>(entity =>
            {
                entity.HasKey(e => e.DataId);

                entity.ToTable("mapstats_data");

                entity.HasIndex(e => e.MapId)
                    .HasName("map_id");

                entity.HasIndex(e => e.ServerId)
                    .HasName("server_id");

                entity.Property(e => e.DataId)
                    .HasColumnName("data_id")
                    .HasColumnType("int(11)");

                entity.Property(e => e.DataInterval)
                    .HasColumnName("data_interval")
                    .HasColumnType("int(11)");

                entity.Property(e => e.MapId)
                    .HasColumnName("map_id")
                    .HasColumnType("int(11)");

                entity.Property(e => e.PlayerCount)
                    .HasColumnName("player_count")
                    .HasColumnType("int(11)");

                entity.Property(e => e.ServerId)
                    .HasColumnName("server_id")
                    .HasColumnType("int(11)");

                entity.Property(e => e.Timestamp)
                    .HasColumnName("timestamp")
                    .HasColumnType("timestamp")
                    .HasDefaultValueSql("'current_timestamp()'");

                entity.HasOne(d => d.Map)
                    .WithMany(p => p.MapstatsData)
                    .HasForeignKey(d => d.MapId)
                    .OnDelete(DeleteBehavior.ClientSetNull)
                    .HasConstraintName("mapstats_data_ibfk_2");

                entity.HasOne(d => d.Server)
                    .WithMany(p => p.MapstatsData)
                    .HasForeignKey(d => d.ServerId)
                    .OnDelete(DeleteBehavior.ClientSetNull)
                    .HasConstraintName("mapstats_data_ibfk_1");
            });

            modelBuilder.Entity<MapstatsMaps>(entity =>
            {
                entity.HasKey(e => e.MapId);

                entity.ToTable("mapstats_maps");

                entity.HasIndex(e => new { e.ServerId, e.MapName })
                    .HasName("server_id")
                    .IsUnique();

                entity.Property(e => e.MapId)
                    .HasColumnName("map_id")
                    .HasColumnType("int(11)");

                entity.Property(e => e.Connects)
                    .HasColumnName("connects")
                    .HasColumnType("int(11)")
                    .HasDefaultValueSql("'0'");

                entity.Property(e => e.Disconnects)
                    .HasColumnName("disconnects")
                    .HasColumnType("int(11)")
                    .HasDefaultValueSql("'0'");

                entity.Property(e => e.MapName)
                    .IsRequired()
                    .HasColumnName("map_name")
                    .HasMaxLength(64);

                entity.Property(e => e.ServerId)
                    .HasColumnName("server_id")
                    .HasColumnType("int(11)");

                entity.HasOne(d => d.Server)
                    .WithMany(p => p.MapstatsMaps)
                    .HasForeignKey(d => d.ServerId)
                    .OnDelete(DeleteBehavior.ClientSetNull)
                    .HasConstraintName("mapstats_maps_ibfk_1");
            });

            modelBuilder.Entity<MapstatsServers>(entity =>
            {
                entity.HasKey(e => e.ServerId);

                entity.ToTable("mapstats_servers");

                entity.HasIndex(e => e.Ip)
                    .HasName("ip")
                    .IsUnique();

                entity.Property(e => e.ServerId)
                    .HasColumnName("server_id")
                    .HasColumnType("int(11)");

                entity.Property(e => e.Ip)
                    .IsRequired()
                    .HasColumnName("ip")
                    .HasMaxLength(16);

                entity.Property(e => e.ServerName)
                    .HasColumnName("server_name")
                    .HasMaxLength(128);

                entity.Property(e => e.Engine)
                    .HasColumnName("engine")
                    .HasMaxLength(32);
            });



        }
    }
}
