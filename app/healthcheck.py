"""Healthcheck Docker: sano se l'ultimo ciclo riuscito e' piu' recente di 3 intervalli (minimo 60s)."""

import os
import sys
import time

from main import HEARTBEAT_FILE, INTERVAL_SECONDS

max_age = max(60, 3 * INTERVAL_SECONDS)
try:
    age = time.time() - os.path.getmtime(HEARTBEAT_FILE)
except FileNotFoundError:
    print("nessun ciclo riuscito finora")
    sys.exit(1)

if age > max_age:
    print(f"ultimo ciclo riuscito {age:.0f}s fa (massimo {max_age}s)")
    sys.exit(1)
print(f"ok, ultimo ciclo riuscito {age:.0f}s fa")
