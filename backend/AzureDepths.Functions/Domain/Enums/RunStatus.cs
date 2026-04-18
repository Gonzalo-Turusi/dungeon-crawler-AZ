namespace AzureDepths.Functions.Domain.Enums;

/// <summary>Lifetime state of a dungeon run (active play vs archived outcomes).</summary>
public enum RunStatus
{
    Active = 0,
    Dead = 1,
    Abandoned = 2
}
