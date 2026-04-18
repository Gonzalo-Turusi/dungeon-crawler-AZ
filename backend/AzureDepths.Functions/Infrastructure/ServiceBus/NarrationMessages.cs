using AzureDepths.Functions.Domain.Enums;

namespace AzureDepths.Functions.Infrastructure.ServiceBus;

/// <summary>Service Bus payload for narrator worker (intro or post-action).</summary>
public sealed record NarrationWorkItem(
    Guid RunId,
    Guid PlayerId,
    Language Language,
    CharacterClass CharacterClass,
    int CurrentFloor,
    NarrationWorkKind Kind);

public enum NarrationWorkKind
{
    Intro = 0,
    AfterAction = 1
}
