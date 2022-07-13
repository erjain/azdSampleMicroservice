FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["Shared/Shared.csproj", "Shared/"]
COPY ["backend/backend.csproj", "backend/"]

RUN dotnet restore "backend/backend.csproj"
COPY . .

WORKDIR "/src/backend"

RUN dotnet publish --no-restore "backend.csproj" -c release -o /app
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
EXPOSE 80
EXPOSE 443
COPY --from=build /app .
ENTRYPOINT ["dotnet", "backend.dll"]