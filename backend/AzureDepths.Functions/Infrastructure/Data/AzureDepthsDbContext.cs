using AzureDepths.Functions.Domain.Entities;
using AzureDepths.Functions.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace AzureDepths.Functions.Infrastructure.Data;

/// <summary>EF Core 10 data access: JSON inventory on <see cref="Run"/> and named filters for active vs archived runs.</summary>
public sealed class AzureDepthsDbContext(DbContextOptions<AzureDepthsDbContext> options) : DbContext(options)
{
    public const string ActiveRunsOnlyFilterName = "ActiveRunsOnly";

    public DbSet<Player> Players => Set<Player>();

    public DbSet<Run> Runs => Set<Run>();

    public DbSet<RunAction> RunActions => Set<RunAction>();

    public DbSet<Leaderboard> LeaderboardEntries => Set<Leaderboard>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Player>(b =>
        {
            b.HasKey(p => p.Id);
            b.Property(p => p.EntraId).HasMaxLength(128);
            b.Property(p => p.Username).HasMaxLength(128);
            b.HasIndex(p => p.EntraId).IsUnique();
        });

        modelBuilder.Entity<Run>(b =>
        {
            b.HasKey(r => r.Id);
            b.HasQueryFilter(ActiveRunsOnlyFilterName, r => r.Status == RunStatus.Active);
            b.HasOne(r => r.Player)
                .WithMany(p => p.Runs)
                .HasForeignKey(r => r.PlayerId)
                .OnDelete(DeleteBehavior.Restrict);

            b.OwnsMany(r => r.Items, owned =>
            {
                owned.ToJson();
                owned.Property(i => i.Name).HasMaxLength(128);
                owned.Property(i => i.Effect).HasMaxLength(512);
            });
        });

        modelBuilder.Entity<RunAction>(b =>
        {
            b.HasKey(a => a.Id);
            b.Property(a => a.ActionType).HasMaxLength(64);
            b.Property(a => a.PlayerInput).HasMaxLength(4000);
            b.Property(a => a.NarratorResponse).HasMaxLength(8000);
            b.HasOne(a => a.Run)
                .WithMany(r => r.Actions)
                .HasForeignKey(a => a.RunId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Leaderboard>(b =>
        {
            b.HasKey(l => l.RunId);
            b.Property(l => l.Username).HasMaxLength(128);
        });
    }
}
