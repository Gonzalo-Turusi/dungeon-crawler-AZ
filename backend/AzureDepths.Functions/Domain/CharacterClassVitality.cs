using AzureDepths.Functions.Domain.Enums;

namespace AzureDepths.Functions.Domain;

/// <summary>C# 14 extension members: baseline HP derived from class without polluting enum declarations.</summary>
public static class CharacterClassVitality
{
    extension(CharacterClass characterClass)
    {
        /// <summary>Starting (current, max) health for a new run.</summary>
        public (int Hp, int MaxHp) StartingVitality => characterClass switch
        {
            CharacterClass.Warrior => (120, 120),
            CharacterClass.Mage => (70, 70),
            CharacterClass.Rogue => (90, 90),
            _ => (100, 100)
        };
    }
}
