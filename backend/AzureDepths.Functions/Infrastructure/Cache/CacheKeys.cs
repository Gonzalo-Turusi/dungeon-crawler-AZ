namespace AzureDepths.Functions.Infrastructure.Cache;

/// <summary>Centralized Redis key shapes: <c>{entity}:{id}</c> per PLAN cache strategy.</summary>
public static class CacheKeys
{
    public const string LeaderboardGlobal = "leaderboard:global";

    public static string Run(Guid runId) => $"run:{runId}";

    public static string Player(Guid playerId) => $"player:{playerId}";
}
