namespace AzureDepths.Functions.Infrastructure.ServiceBus;

/// <summary>Publishes integration messages to Azure Service Bus using managed identity auth.</summary>
public interface IMessagePublisher
{
    Task PublishJsonAsync<T>(string queueName, T message, CancellationToken cancellationToken = default);
}
