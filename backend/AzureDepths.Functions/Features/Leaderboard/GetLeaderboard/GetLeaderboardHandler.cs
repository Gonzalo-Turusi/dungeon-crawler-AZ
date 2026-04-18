using MediatR;

namespace AzureDepths.Functions.Features.Leaderboard.GetLeaderboard;

/// <summary>Placeholder handler — leaderboard aggregation is intentionally deferred.</summary>
public sealed class GetLeaderboardHandler : IRequestHandler<GetLeaderboardQuery, Unit>
{
    /// <summary>
    /// Intentionally throws: leaderboard reads will combine Redis (2-minute TTL) with SQL joins once modeled; keeping
    /// a stub preserves MediatR wiring and folder layout without premature queries.
    /// </summary>
    public Task<Unit> Handle(GetLeaderboardQuery request, CancellationToken cancellationToken) =>
        throw new NotImplementedException($"{nameof(GetLeaderboardHandler)} ships with the leaderboard slice.");
}
