using AzureDepths.Functions.Domain.Enums;

namespace AzureDepths.Functions.Domain.Entities;

/// <summary>Authoritative game state for one descent; items are persisted as JSON on this aggregate.</summary>
public sealed class Run
{
    public Guid Id { get; set; }

    public Guid PlayerId { get; set; }

    public Player? Player { get; set; }

    public CharacterClass Class { get; set; }

    /// <summary>Language used for OpenAI narration prompts (EN/ES).</summary>
    public Language Language { get; set; }

    public int CurrentFloor { get; set; }

    public int Hp
    {
        get => field;
        set => field = value < 0 ? 0 : value;
    }

    public int MaxHp { get; set; }

    public int Gold { get; set; }

    public RunStatus Status { get; set; }

    public DateTimeOffset StartedAt { get; set; }

    public DateTimeOffset? EndedAt { get; set; }

    public List<Item> Items { get; set; } = [];

    public ICollection<RunAction> Actions { get; set; } = new List<RunAction>();
}
