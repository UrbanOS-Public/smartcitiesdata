#!/usr/bin/env python3
"""Fetch discovery_api:query_stats from Redis and pretty-print as JSON.

Requires a port-forward to the Redis instance before running.

Kubernetes (kubectl):
  kubectl port-forward svc/redis 6379:6379 -n <namespace>

k9s:
  Navigate to the redis pod, press <shift-f>, set local port to 6379.

Once the tunnel is open, run this script with no arguments.
"""

import argparse
import json
import os
import sys

try:
    import redis
except ImportError:
    sys.exit("redis-py not installed — run: pip install redis")


REDIS_KEY = "discovery_api:query_stats"

PORTFORWARD_HINT = """\
Port-forward required before running:
  kubectl:  kubectl port-forward svc/redis 6379:6379 -n <namespace>
  k9s:      select redis pod → <shift-f> → set local port 6379
"""


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.parse_args()

    print(PORTFORWARD_HINT, file=sys.stderr)

    password = os.environ.get("REDIS_PASSWORD")
    username = os.environ.get("REDIS_USERNAME")
    client = redis.Redis(host="localhost", port=6379, username=username, password=password, decode_responses=True)

    try:
        raw = client.get(REDIS_KEY)
    except redis.exceptions.AuthenticationError:
        sys.exit(
            "Redis authentication failed — verify REDIS_PASSWORD is correct.\n"
            "If Redis ACL is enabled, also set REDIS_USERNAME."
        )
    except redis.exceptions.ConnectionError as e:
        sys.exit(f"Could not connect to Redis on localhost:6379 — is the port-forward running?\n{e}")

    if raw is None:
        sys.exit(f"Key not found in Redis: {REDIS_KEY}")

    data = json.loads(raw)
    print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
