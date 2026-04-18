using MediatR;

namespace AzureDepths.Functions.Features.Leaderboard.GetLeaderboard;

/// <summary>Query placeholder for the global top-10 leaderboard (Redis + SQL in a later step).</summary>
public sealed record GetLeaderboardQuery : IRequest<Unit>;
