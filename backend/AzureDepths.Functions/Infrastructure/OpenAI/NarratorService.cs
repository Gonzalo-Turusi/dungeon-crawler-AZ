using Azure.AI.OpenAI;
using Azure.Identity;
using Microsoft.Extensions.Configuration;

namespace AzureDepths.Functions.Infrastructure.OpenAI;

/// <summary>Registers an Azure OpenAI client with <see cref="DefaultAzureCredential"/>; chat calls ship in the Narrator slice.</summary>
public sealed class NarratorService(IConfiguration configuration) : INarratorService
{
    private readonly AzureOpenAIClient _client = CreateClient(configuration);
    private readonly string _deploymentName = ResolveDeployment(configuration);

    private static AzureOpenAIClient CreateClient(IConfiguration configuration)
    {
        var endpoint = configuration["AzureOpenAI:Endpoint"]
            ?? throw new InvalidOperationException("Azure OpenAI endpoint is not configured (AzureOpenAI:Endpoint).");
        return new AzureOpenAIClient(new Uri(endpoint), new DefaultAzureCredential());
    }

    private static string ResolveDeployment(IConfiguration configuration) =>
        configuration["AzureOpenAI:DeploymentName"]
        ?? throw new InvalidOperationException("Azure OpenAI deployment is not configured (AzureOpenAI:DeploymentName).");

    /// <inheritdoc />
    public Task<string> NarrateFloorIntroAsync(Guid runId, CancellationToken cancellationToken = default)
    {
        _ = _client;
        return Task.FromException<string>(
            new NotImplementedException(
                $"Narration is asynchronous via Service Bus (deployment '{_deploymentName}'). Implement the Narrator trigger before calling {nameof(INarratorService)} (run {runId})."));
    }
}
