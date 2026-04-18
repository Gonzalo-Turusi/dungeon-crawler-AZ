using MediatR;

namespace AzureDepths.Functions.Features.Narrator.NarrateAction;

/// <summary>Command placeholder for Service Bus–triggered narration (OpenAI integration).</summary>
public sealed record NarrateActionCommand : IRequest<Unit>;
