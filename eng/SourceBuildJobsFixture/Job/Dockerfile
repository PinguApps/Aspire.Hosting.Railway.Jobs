FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source
COPY . .
RUN dotnet publish Job.csproj -c Release -o /output
FROM mcr.microsoft.com/dotnet/runtime:10.0
WORKDIR /app
COPY --from=build /output .
ARG PROOF_VERSION
RUN test -n "$PROOF_VERSION" && printf '%s' "$PROOF_VERSION" > proof.txt
USER $APP_UID
ENTRYPOINT ["dotnet", "Job.dll"]
