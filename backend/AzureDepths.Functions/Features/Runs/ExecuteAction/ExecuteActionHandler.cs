using MediatR;

namespace AzureDepths.Functions.Features.Runs.ExecuteAction;

/// <summary>Placeholder handler — game rules + cache invalidation arrive with the ExecuteAction slice.</summary>
public sealed class ExecuteActionHandler : IRequestHandler<ExecuteActionCommand, Unit>
{
    /// <summary>
    /// Intentionally throws: action resolution, combat rules, and cache invalidation belong in a later slice so this
    /// project can compile while HTTP triggers for Create/Get ship first.
    /// </summary>
    public Task<Unit> Handle(ExecuteActionCommand request, CancellationToken cancellationToken) =>
        throw new NotImplementedException($"{nameof(ExecuteActionHandler)} ships after run creation/read paths.");
}
