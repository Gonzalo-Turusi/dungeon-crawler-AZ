namespace AzureDepths.Functions.Domain.Enums;

/// <summary>Types of encounters that can occur on a dungeon floor.</summary>
public enum FloorEvent
{
    Combat = 0,
    Trap = 1,
    Merchant = 2,
    Rest = 3,
    Boss = 4
}
