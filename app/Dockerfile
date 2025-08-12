# Use the official .NET 8 runtime as base image
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

# Use the .NET 8 SDK for building
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["DotNetMigrationApp.csproj", "."]
RUN dotnet restore "./DotNetMigrationApp.csproj"
COPY . .
WORKDIR "/src/."
RUN dotnet build "DotNetMigrationApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "DotNetMigrationApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Create a non-root user for security
RUN addgroup --system --gid 1001 appgroup
RUN adduser --system --uid 1001 --gid 1001 --no-create-home appuser
RUN chown -R appuser:appgroup /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["dotnet", "DotNetMigrationApp.dll"]
