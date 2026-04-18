namespace AzureDepths.Functions.Infrastructure.Cache;

/// <summary>TTLs from PLAN.md — keep cache lifetimes in one place for operational tuning.</summary>
public static class CacheTtl
{
    public static readonly TimeSpan RunState = TimeSpan.FromMinutes(5);

    public static readonly TimeSpan Leaderboard = TimeSpan.FromMinutes(2);

    public static readonly TimeSpan Player = TimeSpan.FromMinutes(10);

    public static readonly TimeSpan FloorConfig = TimeSpan.FromHours(1);
}
