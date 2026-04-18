using MediatR;

namespace AzureDepths.Functions.Features.Runs.ExecuteAction;

/// <summary>Command placeholder for processing a player action (implemented in a later step).</summary>
public sealed record ExecuteActionCommand : IRequest<Unit>;
