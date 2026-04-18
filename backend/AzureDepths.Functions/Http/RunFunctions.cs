using System.Text.Json;
using AzureDepths.Functions.Features.Runs.CreateRun;
using AzureDepths.Functions.Features.Runs.GetRunState;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace AzureDepths.Functions.Http;

/// <summary>Thin HTTP adapters — all behavior lives in MediatR handlers per vertical slice architecture.</summary>
internal sealed class RunFunctions(IMediator mediator, ILogger<RunFunctions> logger)
{
    /// <summary>POST /runs → dispatches <see cref="CreateRunCommand"/>.</summary>
    [Function(nameof(CreateRun))]
    public async Task<IActionResult> CreateRun(
        [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "runs")] HttpRequest req,
        CancellationToken cancellationToken)
    {
        try
        {
            var command = await JsonSerializer.DeserializeAsync<CreateRunCommand>(
                    req.Body,
                    JsonSerializerOptions.Web,
                    cancellationToken)
                .ConfigureAwait(false);

            if (command is null)
            {
                return new BadRequestObjectResult(new { error = "Request body is required." });
            }

            var result = await mediator.Send(command, cancellationToken).ConfigureAwait(false);
            return new OkObjectResult(result);
        }
        catch (CreateRunValidationException ex)
        {
            logger.LogWarning(ex, "Create run validation failed.");
            return new BadRequestObjectResult(new { error = ex.Message });
        }
        catch (JsonException ex)
        {
            logger.LogWarning(ex, "Invalid JSON for create run.");
            return new BadRequestObjectResult(new { error = "Invalid JSON payload." });
        }
    }

    /// <summary>GET /runs/{runId:guid} → dispatches <see cref="GetRunStateQuery"/>.</summary>
    [Function(nameof(GetRunState))]
    public async Task<IActionResult> GetRunState(
        [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "runs/{runId:guid}")] HttpRequest req,
        Guid runId,
        CancellationToken cancellationToken)
    {
        var dto = await mediator.Send(new GetRunStateQuery(runId), cancellationToken).ConfigureAwait(false);
        return dto is null ? new NotFoundResult() : new OkObjectResult(dto);
    }
}
