using MediatR;

namespace AzureDepths.Functions.Features.Narrator.NarrateAction;

/// <summary>Placeholder handler — narrator worker will deserialize Service Bus payloads and call Azure OpenAI.</summary>
public sealed class NarrateActionHandler : IRequestHandler<NarrateActionCommand, Unit>
{
    /// <summary>
    /// Intentionally throws: the Service Bus–triggered narrator will deserialize work items, call Azure OpenAI with
    /// Managed Identity, and persist narrator text — none of which is required for the first HTTP slices.
    /// </summary>
    public Task<Unit> Handle(NarrateActionCommand request, CancellationToken cancellationToken) =>
        throw new NotImplementedException($"{nameof(NarrateActionHandler)} ships with the Narrator function trigger.");
}
