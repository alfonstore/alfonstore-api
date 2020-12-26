### Build and install packages
FROM python:3.9 as build-python

RUN apt-get -y update \
  && apt-get install -y gettext \
  # Cleanup apt cache
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Copy environment variables
COPY .env /app/

# Install Python dependencies
COPY requirements_dev.txt /app/
WORKDIR /app
RUN pip install -r requirements_dev.txt

### Final image
FROM python:3.9-slim

RUN groupadd -r saleor && useradd -r -g saleor saleor

RUN apt-get update \
  && apt-get install -y \
  libxml2 \
  libssl1.1 \
  libcairo2 \
  libpango-1.0-0 \
  libpangocairo-1.0-0 \
  libgdk-pixbuf2.0-0 \
  shared-mime-info \
  mime-support \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/media /app/static \
  && chown -R saleor:saleor /app/

COPY --from=build-python /usr/local/lib/python3.9/site-packages/ /usr/local/lib/python3.9/site-packages/
COPY --from=build-python /usr/local/bin/ /usr/local/bin/
COPY . /app
WORKDIR /app

ARG STATIC_URL
ENV STATIC_URL ${STATIC_URL:-/static/}
ARG DATABASE_URL
ENV DATABASE_URL ${DATABASE_URL:-postgres://saleor:saleor@localhost:5432/saleor}
RUN SECRET_KEY=dummy STATIC_URL=${STATIC_URL} DATABASE_URL=${DATABASE_URL} python3 manage.py collectstatic --no-input

EXPOSE 6969
ENV PYTHONUNBUFFERED 1

ARG COMMIT_ID
ARG PROJECT_VERSION
ENV PROJECT_VERSION="${PROJECT_VERSION}"

LABEL org.opencontainers.image.title="mirumee/saleor"                                  \
      org.opencontainers.image.description="\
A modular, high performance, headless e-commerce platform built with Python, \
GraphQL, Django, and ReactJS."                                                         \
      org.opencontainers.image.url="https://saleor.io/"                                \
      org.opencontainers.image.source="https://github.com/mirumee/saleor"              \
      org.opencontainers.image.revision="$COMMIT_ID"                                   \
      org.opencontainers.image.version="$PROJECT_VERSION"                              \
      org.opencontainers.image.authors="Mirumee Software (https://mirumee.com)"        \
      org.opencontainers.image.licenses="BSD 3"

ARG SSL_CERTFILE
ENV SSL_CERTFILE ${SSL_CERTFILE:-""}

ARG SSL_KEYFILE
ENV SSL_KEYFILE ${SSL_KEYFILE:-""}

CMD gunicorn --bind :6969 --workers 4 --certfile ${SSL_CERTFILE} --keyfile ${SSL_KEYFILE} --worker-class uvicorn.workers.UvicornWorker saleor.asgi:application
#CMD ["gunicorn", "--bind", ":6969", "--workers", "4", "--certfile", "${SSL_CERTFILE}", "--keyfile", "${SSL_KEYFILE}", "--worker-class", "uvicorn.workers.UvicornWorker", "saleor.asgi:application"]
