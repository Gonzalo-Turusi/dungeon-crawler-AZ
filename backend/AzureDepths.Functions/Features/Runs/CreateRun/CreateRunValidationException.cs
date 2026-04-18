namespace AzureDepths.Functions.Features.Runs.CreateRun;

/// <summary>Domain validation failure for run creation (maps to HTTP 400 at the function boundary).</summary>
public sealed class CreateRunValidationException(string message) : Exception(message);
