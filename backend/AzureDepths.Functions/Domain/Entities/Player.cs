namespace AzureDepths.Functions.Domain.Entities;

/// <summary>Registered player identity linked to Entra ID for auth and run ownership.</summary>
public sealed class Player
{
    public Guid Id { get; set; }

    public required string EntraId { get; set; }

    public required string Username { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public ICollection<Run> Runs { get; set; } = new List<Run>();
}
