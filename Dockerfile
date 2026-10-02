FROM python:3.12-slim

# Versione iniettata in fase di build (dalla GitHub Action, dal tag git vX.Y.Z)
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

LABEL org.opencontainers.image.title="nextgendevops" \
      org.opencontainers.image.version="${APP_VERSION}"

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

RUN useradd --create-home --uid 1000 appuser
USER appuser

CMD ["python", "main.py"]
