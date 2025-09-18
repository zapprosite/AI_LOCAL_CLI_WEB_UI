#!/usr/bin/env python3
import requests, sys

QDRANT = "http://localhost:6333"

collections = ["agents_kb", "docs_kb"]

for c in collections:
    r = requests.put(f"{QDRANT}/collections/{c}", json={
        "vectors": {"size": 1536, "distance": "Cosine"}
    })
    print(f"Seeded {c}: {r.status_code} {r.text}")
