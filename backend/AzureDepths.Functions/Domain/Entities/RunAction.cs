namespace AzureDepths.Functions.Domain.Entities;

/// <summary>One player action and the narrator response for run history / audit.</summary>
public sealed class RunAction
{
    public Guid Id { get; set; }

    public Guid RunId { get; set; }

    public Run? Run { get; set; }

    public int Floor { get; set; }

    public required string ActionType { get; set; }

    public string? PlayerInput { get; set; }

    public string? NarratorResponse { get; set; }

    public DateTimeOffset Timestamp { get; set; }
}
