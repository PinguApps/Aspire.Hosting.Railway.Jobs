FROM mcr.microsoft.com/dotnet/sdk:10.0@sha256:212fe4cb74627d5adf9817a4088906ae3edff1bd853bb27565d4b46731efe61e AS build
WORKDIR /source
COPY . .
RUN dotnet publish Job.csproj -c Release -o /output
FROM mcr.microsoft.com/dotnet/runtime:10.0@sha256:4f1f30cf0bb4ab0c8b2daa84613051683456f8df4a9bf7c812e20d74962992ac
WORKDIR /app
COPY --from=build /output .
ARG PROOF_VERSION
RUN test -n "$PROOF_VERSION" && printf '%s' "$PROOF_VERSION" > proof.txt
USER $APP_UID
ENTRYPOINT ["dotnet", "Job.dll"]
