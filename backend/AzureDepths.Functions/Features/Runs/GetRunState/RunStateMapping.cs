using AzureDepths.Functions.Domain.Entities;

namespace AzureDepths.Functions.Features.Runs.GetRunState;

/// <summary>C# 14 extension members: maps persistence model to cache/API DTO in one place.</summary>
public static class RunStateMapping
{
    extension(Run run)
    {
        /// <summary>Projects a tracked <see cref="Run"/> into an immutable DTO for Redis/API responses.</summary>
        public RunStateDto ToRunStateDto()
        {
            var items = run.Items
                .OrderBy(i => i.Slot)
                .Select(i => new ItemDto(i.Id, i.Name, i.Effect, i.Slot))
                .ToList();

            return new RunStateDto(
                run.Id,
                run.PlayerId,
                run.Class,
                run.Language,
                run.CurrentFloor,
                run.Hp,
                run.MaxHp,
                run.Gold,
                run.Status,
                run.StartedAt,
                run.EndedAt,
                items);
        }
    }
}
