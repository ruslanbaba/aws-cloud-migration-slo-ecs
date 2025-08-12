using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Serilog;
using System.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .Enrich.WithProperty("Application", "DotNetMigrationApp")
    .Enrich.WithProperty("Environment", builder.Environment.EnvironmentName)
    .CreateLogger();

builder.Host.UseSerilog();

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Add health checks
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy("Application is running"))
    .AddCheck("database", () => HealthCheckResult.Healthy("Database connection is healthy"))
    .AddCheck("external_api", () => HealthCheckResult.Healthy("External API is reachable"));

// Add Application Insights
builder.Services.AddApplicationInsightsTelemetry();

// Add custom services
builder.Services.AddScoped<IWeatherService, WeatherService>();

// Configure CORS for development
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(builder =>
        {
            builder.AllowAnyOrigin()
                   .AllowAnyMethod()
                   .AllowAnyHeader();
        });
    });
}

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
    app.UseCors();
}

app.UseHttpsRedirection();

// Add custom middleware for request logging
app.Use(async (context, next) =>
{
    var stopwatch = Stopwatch.StartNew();
    var correlationId = Guid.NewGuid().ToString();
    
    using (Log.ForContext("CorrelationId", correlationId))
    {
        Log.Information("Processing request {Method} {Path}", 
            context.Request.Method, context.Request.Path);
        
        context.Response.Headers.Add("X-Correlation-ID", correlationId);
        
        await next();
        
        stopwatch.Stop();
        
        Log.Information("Completed request {Method} {Path} in {ElapsedMs}ms with status {StatusCode}",
            context.Request.Method, context.Request.Path, stopwatch.ElapsedMilliseconds, context.Response.StatusCode);
    }
});

// Health check endpoints
app.MapHealthChecks("/health", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        var response = new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(x => new
            {
                name = x.Key,
                status = x.Value.Status.ToString(),
                description = x.Value.Description,
                duration = x.Value.Duration.TotalMilliseconds
            }),
            totalDuration = report.TotalDuration.TotalMilliseconds
        };
        await context.Response.WriteAsync(System.Text.Json.JsonSerializer.Serialize(response));
    }
});

app.MapHealthChecks("/health/ready");
app.MapHealthChecks("/health/live");

app.UseAuthorization();

app.MapControllers();

// Add sample endpoints
app.MapGet("/", () => new
{
    Application = "DotNet Migration App",
    Version = "1.0.0",
    Environment = app.Environment.EnvironmentName,
    Timestamp = DateTime.UtcNow,
    MachineName = Environment.MachineName,
    ProcessId = Environment.ProcessId
});

app.MapGet("/api/weather", async (IWeatherService weatherService) =>
{
    Log.Information("Weather endpoint called");
    return await weatherService.GetWeatherForecastAsync();
});

try
{
    Log.Information("Starting application");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

// Weather Service Interface and Implementation
public interface IWeatherService
{
    Task<IEnumerable<WeatherForecast>> GetWeatherForecastAsync();
}

public class WeatherService : IWeatherService
{
    private static readonly string[] Summaries = new[]
    {
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    };

    private readonly ILogger<WeatherService> _logger;

    public WeatherService(ILogger<WeatherService> logger)
    {
        _logger = logger;
    }

    public async Task<IEnumerable<WeatherForecast>> GetWeatherForecastAsync()
    {
        _logger.LogInformation("Generating weather forecast");
        
        // Simulate async operation
        await Task.Delay(Random.Shared.Next(10, 100));
        
        var forecast = Enumerable.Range(1, 5).Select(index => new WeatherForecast
        {
            Date = DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            TemperatureC = Random.Shared.Next(-20, 55),
            Summary = Summaries[Random.Shared.Next(Summaries.Length)]
        }).ToArray();
        
        _logger.LogInformation("Generated {Count} weather forecasts", forecast.Length);
        return forecast;
    }
}

public record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
