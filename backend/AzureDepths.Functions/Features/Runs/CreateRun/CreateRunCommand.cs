using AzureDepths.Functions.Domain.Enums;
using MediatR;

namespace AzureDepths.Functions.Features.Runs.CreateRun;

/// <summary>Command to start a new active run for an existing player.</summary>
public sealed record CreateRunCommand(Guid PlayerId, CharacterClass CharacterClass, Language Language)
    : IRequest<CreateRunResult>;

/// <summary>Identifier returned to the client after the run row is committed.</summary>
public sealed record CreateRunResult(Guid RunId);
