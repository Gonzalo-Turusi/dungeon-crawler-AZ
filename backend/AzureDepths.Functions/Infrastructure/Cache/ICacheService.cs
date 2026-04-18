namespace AzureDepths.Functions.Infrastructure.Cache;

/// <summary>Typed cache-aside abstraction so handlers never depend on StackExchange.Redis directly.</summary>
public interface ICacheService
{
    Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default);

    Task SetAsync<T>(string key, T value, TimeSpan ttl, CancellationToken cancellationToken = default);

    Task InvalidateAsync(string key, CancellationToken cancellationToken = default);
}
