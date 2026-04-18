namespace AzureDepths.Functions.Domain.Entities;

/// <summary>Inventory entry stored as JSON on <see cref="Run"/> (EF Core JSON column mapping).</summary>
public sealed class Item
{
    public Guid Id { get; set; }

    public required string Name { get; set; }

    public required string Effect { get; set; }

    public int Slot { get; set; }
}
