using AzureDepths.Functions.Infrastructure.Cache;
using AzureDepths.Functions.Infrastructure.Data;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace AzureDepths.Functions.Features.Runs.GetRunState;

/// <summary>
/// Reads run state via Redis (pattern run:{{id}}) first to protect SQL; on miss loads from SQL with the
/// archived-run filter disabled so dead/abandoned runs remain readable, then repopulates cache (5 min TTL).
/// </summary>
public sealed class GetRunStateHandler(
    ICacheService cache,
    IDbContextFactory<AzureDepthsDbContext> dbFactory)
    : IRequestHandler<GetRunStateQuery, RunStateDto?>
{
    /// <summary>
    /// Implements cache-aside: return warm Redis JSON if present, otherwise load SQL with archived runs visible,
    /// project to a DTO, and seed Redis using the run-state TTL from PLAN to shield the database from read storms.
    /// </summary>
    public async Task<RunStateDto?> Handle(GetRunStateQuery request, CancellationToken cancellationToken)
    {
        var cacheKey = CacheKeys.Run(request.RunId);

        var cached = await cache.GetAsync<RunStateDto>(cacheKey, cancellationToken).ConfigureAwait(false);
        if (cached is not null)
        {
            return cached;
        }

        await using var db = await dbFactory.CreateDbContextAsync(cancellationToken).ConfigureAwait(false);

        var run = await db.Runs
            .IgnoreQueryFilters([AzureDepthsDbContext.ActiveRunsOnlyFilterName])
            .AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == request.RunId, cancellationToken)
            .ConfigureAwait(false);

        if (run is null)
        {
            return null;
        }

        var dto = run.ToRunStateDto();
        await cache.SetAsync(cacheKey, dto, CacheTtl.RunState, cancellationToken).ConfigureAwait(false);
        return dto;
    }
}
