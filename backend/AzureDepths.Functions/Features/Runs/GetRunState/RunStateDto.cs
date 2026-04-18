using AzureDepths.Functions.Domain.Entities;
using AzureDepths.Functions.Domain.Enums;

namespace AzureDepths.Functions.Features.Runs.GetRunState;

/// <summary>API/cache projection of <see cref="Run"/> for fast reads.</summary>
public sealed record RunStateDto(
    Guid RunId,
    Guid PlayerId,
    CharacterClass Class,
    Language Language,
    int CurrentFloor,
    int Hp,
    int MaxHp,
    int Gold,
    RunStatus Status,
    DateTimeOffset StartedAt,
    DateTimeOffset? EndedAt,
    IReadOnlyList<ItemDto> Items);

public sealed record ItemDto(Guid Id, string Name, string Effect, int Slot);
