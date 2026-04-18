using AzureDepths.Functions.Domain;
using AzureDepths.Functions.Domain.Entities;
using AzureDepths.Functions.Domain.Enums;
using AzureDepths.Functions.Infrastructure.Data;
using AzureDepths.Functions.Infrastructure.ServiceBus;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace AzureDepths.Functions.Features.Runs.CreateRun;

/// <summary>
/// Creates a new <see cref="Run"/>, persists it with Managed Identity SQL access, then publishes an intro
/// narration job to Service Bus so gameplay stays decoupled from OpenAI latency.
/// </summary>
public sealed class CreateRunHandler(
    IDbContextFactory<AzureDepthsDbContext> dbFactory,
    CreateRunValidator validator,
    IMessagePublisher messagePublisher,
    IConfiguration configuration)
    : IRequestHandler<CreateRunCommand, CreateRunResult>
{
    /// <summary>
    /// Validates the player, applies class baselines, persists the active run (honoring the EF active-only filter),
    /// and enqueues intro narration so the HTTP path stays fast while Azure OpenAI works asynchronously.
    /// </summary>
    public async Task<CreateRunResult> Handle(CreateRunCommand request, CancellationToken cancellationToken)
    {
        await validator.ValidateAsync(request, cancellationToken).ConfigureAwait(false);

        var (hp, maxHp) = request.CharacterClass.StartingVitality;

        var run = new Run
        {
            Id = Guid.NewGuid(),
            PlayerId = request.PlayerId,
            Class = request.CharacterClass,
            Language = request.Language,
            CurrentFloor = 1,
            Hp = hp,
            MaxHp = maxHp,
            Gold = 0,
            Status = RunStatus.Active,
            StartedAt = DateTimeOffset.UtcNow,
            Items = []
        };

        await using (var db = await dbFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false))
        {
            db.Runs.Add(run);
            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        }

        var queueName = configuration["Narration:QueueName"]
            ?? throw new InvalidOperationException("Narration queue is not configured (Narration:QueueName).");

        var workItem = new NarrationWorkItem(
            run.Id,
            run.PlayerId,
            run.Language,
            run.Class,
            run.CurrentFloor,
            NarrationWorkKind.Intro);

        await messagePublisher.PublishJsonAsync(queueName, workItem, cancellationToken).ConfigureAwait(false);

        return new CreateRunResult(run.Id);
    }
}
