using System.Text.Json;
using StackExchange.Redis;

namespace AzureDepths.Functions.Infrastructure.Cache;

/// <summary>Redis implementation of <see cref="ICacheService"/> using JSON payloads.</summary>
public sealed class RedisCacheService(IConnectionMultiplexer multiplexer) : ICacheService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false
    };

    /// <inheritdoc />
    public async Task<T?> GetAsync<T>(string key, CancellationToken cancellationToken = default)
    {
        var db = multiplexer.GetDatabase();
        var value = await db.StringGetAsync(key).WaitAsync(cancellationToken).ConfigureAwait(false);
        if (value.IsNullOrEmpty)
        {
            return default;
        }

        return JsonSerializer.Deserialize<T>(value.ToString(), JsonOptions);
    }

    /// <inheritdoc />
    public async Task SetAsync<T>(string key, T value, TimeSpan ttl, CancellationToken cancellationToken = default)
    {
        var db = multiplexer.GetDatabase();
        var json = JsonSerializer.Serialize(value, JsonOptions);
        await db.StringSetAsync(key, json, ttl).WaitAsync(cancellationToken).ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task InvalidateAsync(string key, CancellationToken cancellationToken = default)
    {
        var db = multiplexer.GetDatabase();
        await db.KeyDeleteAsync(key).WaitAsync(cancellationToken).ConfigureAwait(false);
    }
}
