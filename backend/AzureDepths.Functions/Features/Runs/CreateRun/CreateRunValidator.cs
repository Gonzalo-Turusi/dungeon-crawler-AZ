using AzureDepths.Functions.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace AzureDepths.Functions.Features.Runs.CreateRun;

/// <summary>Validates create-run preconditions (player must exist) before mutating game state.</summary>
public sealed class CreateRunValidator(IDbContextFactory<AzureDepthsDbContext> dbFactory)
{
    /// <summary>
    /// Confirms the foreign key target exists because SQL constraints may arrive later than this learning milestone,
    /// and failing fast keeps MediatR handlers honest without silent bad data.
    /// </summary>
    public async Task ValidateAsync(CreateRunCommand command, CancellationToken cancellationToken)
    {
        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);
        var exists = await db.Players
            .AnyAsync(p => p.Id == command.PlayerId, cancellationToken)
            .ConfigureAwait(false);

        if (!exists)
        {
            throw new CreateRunValidationException($"Player '{command.PlayerId}' was not found.");
        }
    }
}
