FROM mcr.microsoft.com/azure-cli:latest-amd64 AS base
WORKDIR /app
COPY ["setup.sh","setup.sh"]
COPY ["cleaner.sh","cleaner.sh"]

RUN chmod +x ./setup.sh
RUN chmod +x ./cleaner.sh

RUN ./setup.sh

ENTRYPOINT ["sh", "cleaner.sh" ]