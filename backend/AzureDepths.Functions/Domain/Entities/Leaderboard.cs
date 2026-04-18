namespace AzureDepths.Functions.Domain.Entities;

/// <summary>Archived permadeath outcome surfaced on the global leaderboard.</summary>
public sealed class Leaderboard
{
    public Guid RunId { get; set; }

    public Guid PlayerId { get; set; }

    public required string Username { get; set; }

    public int FloorsCleared { get; set; }

    public int MonstersKilled { get; set; }

    public DateTimeOffset DiedAt { get; set; }
}
