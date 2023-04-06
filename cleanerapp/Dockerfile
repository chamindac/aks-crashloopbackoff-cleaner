FROM mcr.microsoft.com/azure-cli:latest-amd64 AS base
WORKDIR /app
COPY ["setup.sh",""]
COPY ["cleaner.sh",""]

RUN ./setup.sh

ENTRYPOINT ["sh", "cleaner.sh" ]