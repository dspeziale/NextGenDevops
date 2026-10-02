"""NextGenDevops collector.

Scarica periodicamente il meteo corrente da Open-Meteo (API pubblica, senza chiave)
per alcune citta' e salva le letture in PostgreSQL.
"""

import logging
import os
import signal
import sys
import time

import psycopg
import requests

APP_VERSION = os.getenv("APP_VERSION", "dev")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://app:app@db:5432/nextgen")
INTERVAL_SECONDS = int(os.getenv("INTERVAL_SECONDS", "10"))
# aggiornato dopo ogni ciclo con almeno una lettura salvata; lo controlla healthcheck.py
HEARTBEAT_FILE = "/tmp/heartbeat"

# nome -> (latitudine, longitudine)
CITIES = {
    "Roma": (41.89, 12.49),
    "Milano": (45.46, 9.19),
    "Napoli": (40.85, 14.27),
    "Torino": (45.07, 7.69),
    "Palermo": (38.12, 13.36),
}

OPEN_METEO_URL = "https://api.open-meteo.com/v1/forecast"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [v" + APP_VERSION + "] %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("collector")

SCHEMA = """
CREATE TABLE IF NOT EXISTS weather_readings (
    id            BIGSERIAL PRIMARY KEY,
    city          TEXT        NOT NULL,
    latitude      DOUBLE PRECISION NOT NULL,
    longitude     DOUBLE PRECISION NOT NULL,
    temperature_c DOUBLE PRECISION,
    windspeed_kmh DOUBLE PRECISION,
    weathercode   INTEGER,
    observed_at   TIMESTAMPTZ,
    collected_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    app_version   TEXT        NOT NULL
);
"""

running = True


def stop(signum, _frame):
    global running
    log.info("Ricevuto segnale %s, arresto in corso", signum)
    running = False


def connect(retries: int = 30, delay: int = 2) -> psycopg.Connection:
    for attempt in range(1, retries + 1):
        try:
            conn = psycopg.connect(DATABASE_URL, autocommit=True)
            log.info("Connesso a PostgreSQL")
            return conn
        except psycopg.OperationalError as exc:
            log.warning("DB non raggiungibile (tentativo %d/%d): %s", attempt, retries, exc)
            time.sleep(delay)
    raise SystemExit("Impossibile connettersi al database")


def fetch(city: str, lat: float, lon: float) -> dict:
    resp = requests.get(
        OPEN_METEO_URL,
        params={"latitude": lat, "longitude": lon, "current_weather": "true", "timezone": "UTC"},
        timeout=15,
    )
    resp.raise_for_status()
    cw = resp.json()["current_weather"]
    return {
        "city": city,
        "latitude": lat,
        "longitude": lon,
        "temperature_c": cw.get("temperature"),
        "windspeed_kmh": cw.get("windspeed"),
        "weathercode": cw.get("weathercode"),
        "observed_at": cw.get("time"),
        "app_version": APP_VERSION,
    }


def collect(conn: psycopg.Connection) -> None:
    saved = 0
    for city, (lat, lon) in CITIES.items():
        try:
            row = fetch(city, lat, lon)
        except requests.RequestException as exc:
            log.error("Errore download %s: %s", city, exc)
            continue
        conn.execute(
            """
            INSERT INTO weather_readings
                (city, latitude, longitude, temperature_c, windspeed_kmh,
                 weathercode, observed_at, app_version)
            VALUES (%(city)s, %(latitude)s, %(longitude)s, %(temperature_c)s,
                    %(windspeed_kmh)s, %(weathercode)s, %(observed_at)s, %(app_version)s)
            """,
            row,
        )
        saved += 1
        log.info("%s: %s C, vento %s km/h", city, row["temperature_c"], row["windspeed_kmh"])
    log.info("Ciclo completato: %d/%d letture salvate", saved, len(CITIES))
    if saved:
        with open(HEARTBEAT_FILE, "w") as f:
            f.write(str(time.time()))


def main() -> None:
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    log.info("Avvio NextGenDevops collector versione %s (intervallo %ss)", APP_VERSION, INTERVAL_SECONDS)

    conn = connect()
    conn.execute(SCHEMA)

    while running:
        try:
            collect(conn)
        except psycopg.Error as exc:
            log.error("Errore database: %s, riconnessione", exc)
            conn = connect()
        for _ in range(INTERVAL_SECONDS):
            if not running:
                break
            time.sleep(1)

    conn.close()
    log.info("Arrestato")


if __name__ == "__main__":
    main()
