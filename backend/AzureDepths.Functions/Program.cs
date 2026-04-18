using System.Reflection;
using Azure.Extensions.AspNetCore.Configuration.Secrets;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using AzureDepths.Functions.Features.Runs.CreateRun;
using AzureDepths.Functions.Features.Runs.ExecuteAction;
using AzureDepths.Functions.Infrastructure.Cache;
using AzureDepths.Functions.Infrastructure.Data;
using AzureDepths.Functions.Infrastructure.OpenAI;
using AzureDepths.Functions.Infrastructure.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using StackExchange.Redis;

var builder = FunctionsApplication.CreateBuilder(args);

var keyVaultUri = builder.Configuration["KeyVaultUri"];
if (!string.IsNullOrWhiteSpace(keyVaultUri))
{
    ((IConfigurationBuilder)builder.Configuration).AddAzureKeyVault(
        new Uri(keyVaultUri),
        new DefaultAzureCredential());
}

builder.ConfigureFunctionsWebApplication();

builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights();

builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(Assembly.GetExecutingAssembly()));

var sqlConnectionString = builder.Configuration["ConnectionStrings:AzureDepths"]
    ?? throw new InvalidOperationException(
        "Connection string 'AzureDepths' is missing. Configure ConnectionStrings__AzureDepths (Managed Identity SQL; no user/password secret).");

builder.Services.AddDbContextFactory<AzureDepthsDbContext>(options =>
    options.UseSqlServer(sqlConnectionString));

var redisConnection = builder.Configuration["Redis:ConnectionString"]
    ?? throw new InvalidOperationException(
        "Redis connection string missing. Provide Key Vault secret Redis--ConnectionString or Redis__ConnectionString for local development.");

builder.Services.AddSingleton<IConnectionMultiplexer>(_ => ConnectionMultiplexer.Connect(redisConnection));

builder.Services.AddSingleton<ICacheService, RedisCacheService>();

var serviceBusNamespace = builder.Configuration["ServiceBusConnection:fullyQualifiedNamespace"]
    ?? throw new InvalidOperationException(
        "Service Bus namespace missing. Set ServiceBusConnection__fullyQualifiedNamespace.");

var credential = new DefaultAzureCredential();
builder.Services.AddSingleton(_ => new ServiceBusClient(serviceBusNamespace, credential));
builder.Services.AddSingleton<IMessagePublisher, ServiceBusPublisher>();

builder.Services.AddSingleton<INarratorService, NarratorService>();
builder.Services.AddSingleton<CreateRunValidator>();
builder.Services.AddSingleton<ExecuteActionValidator>();

builder.Build().Run();
