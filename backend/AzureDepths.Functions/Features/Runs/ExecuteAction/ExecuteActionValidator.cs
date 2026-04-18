namespace AzureDepths.Functions.Features.Runs.ExecuteAction;

/// <summary>Validator placeholder mirroring the CreateRun pattern; rules land with ExecuteAction.</summary>
public sealed class ExecuteActionValidator
{
    /// <summary>No-op today — exists so DI and folder layout match the vertical slice template.</summary>
    public Task ValidateAsync(ExecuteActionCommand command, CancellationToken cancellationToken) =>
        Task.CompletedTask;
}
