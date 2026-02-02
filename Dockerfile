FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Installera .NET 8 runtime + basverktyg
RUN apt-get update && \
    apt-get install -y \
      ca-certificates \
      tzdata \
      curl \
      unzip \
      dotnet-runtime-8.0 \
      && rm -rf /var/lib/apt/lists/*

# (valfritt men bra) kontroll så dotnet verkligen finns i imagen
RUN dotnet --info

# Arbetskatalog
WORKDIR /app

# Kopiera WebGrab-filer
COPY wg/ /app/wg/

# Skapa output-mapp
RUN mkdir -p /out

# Kör från wg-mappen så WebGrab hittar siteini.pack m.m.
WORKDIR /app/wg

# Kör WebGrab och peka på CONFIG_FOLDER (mappen som innehåller WebGrab++.config.xml)
CMD ["dotnet", "/app/wg/bin.net/WebGrab+Plus.dll", "/app/wg"]
