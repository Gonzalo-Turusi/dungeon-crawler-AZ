using MediatR;

namespace AzureDepths.Functions.Features.Runs.GetRunState;

/// <summary>Query for the latest persisted run projection, using Redis cache-aside per PLAN.</summary>
public sealed record GetRunStateQuery(Guid RunId) : IRequest<RunStateDto?>;
