namespace AzureDepths.Functions.Infrastructure.OpenAI;

/// <summary>Azure OpenAI wrapper for dungeon narration (implemented fully in the Narrator slice).</summary>
public interface INarratorService
{
    Task<string> NarrateFloorIntroAsync(Guid runId, CancellationToken cancellationToken = default);
}
