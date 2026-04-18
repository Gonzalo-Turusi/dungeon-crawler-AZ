using System.Text.Json;
using Azure.Messaging.ServiceBus;

namespace AzureDepths.Functions.Infrastructure.ServiceBus;

/// <summary><see cref="IMessagePublisher"/> backed by <see cref="ServiceBusClient"/> (namespace + AAD).</summary>
public sealed class ServiceBusPublisher(ServiceBusClient client) : IMessagePublisher
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    /// <inheritdoc />
    public async Task PublishJsonAsync<T>(string queueName, T message, CancellationToken cancellationToken = default)
    {
        await using var sender = client.CreateSender(queueName);
        var body = JsonSerializer.SerializeToUtf8Bytes(message, JsonOptions);
        var sbMessage = new ServiceBusMessage(body)
        {
            ContentType = "application/json"
        };
        await sender.SendMessageAsync(sbMessage, cancellationToken).ConfigureAwait(false);
    }
}
