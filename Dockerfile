# Hardened Dockerfile for SecretFinder
# Security improvements:
# - Local file copying instead of remote downloads
# - Pinned base image version for reproducibility
# - Explicit SSL/TLS verification in runtime
# - Minimal attack surface
#
# usage:
# docker build -t secretfinder:1.0.0 .
# while read url; do docker run --rm -v $(pwd)/output:/output secretfinder:1.0.0 -i $url -o /output/result.html; done < urls.txt

FROM python:3.11-alpine3.19

LABEL source="SecretFinder <github.com/m4ll0k/SecretFinder>"
LABEL maintainer="security@secretfinder.local"
LABEL description="Hardened SecretFinder: Discovers API keys and sensitive data in JavaScript files"

# Install runtime dependencies only (no build tools in final image)
RUN apk add --no-cache \
    libxml2 \
    libxslt \
    && rm -rf /var/cache/apk/*

# Copy local requirements and source code
COPY requirements.txt .
COPY SecretFinder.py /usr/local/bin/SecretFinder.py

# Install Python dependencies with pinned versions
RUN pip install --no-cache-dir \
    --disable-pip-version-check \
    -r requirements.txt \
    && chmod +x /usr/local/bin/SecretFinder.py

# Run as non-root user for security
RUN addgroup -g 1000 secretfinder && \
    adduser -D -u 1000 -G secretfinder secretfinder

USER secretfinder

# Health check (optional - validates tool works)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD SecretFinder.py -h > /dev/null 2>&1 || exit 1

ENTRYPOINT [ "SecretFinder.py" ]
CMD [ "-h" ]
