#!/usr/bin/env python3
"""
MEM_CLI: Upsert text into Qdrant with LiteLLM embeddings (stdlib only).

- Ensures Qdrant collection exists (size=384, cosine, on_disk=true via HNSW).
- Embeds the provided text using LiteLLM /embeddings (model=EMBED_MODEL).
- Upserts a new point with payload { "text": "<input>" }.
- Prints the new point ID to stdout.

Env:
- LITELLM_BASE (default: http://litellm:4000/v1)
- LITELLM_MASTER_KEY (optional, Bearer token)
- QDRANT_URL (default: http://qdrant:6333)
- QDRANT_COLL (default: mem_long)
- EMBED_MODEL (default: embed.local)

Usage:
  MEM_CLI.py "some text to store"
  MEM_CLI.py -   # reads text from stdin
"""
import os
import sys
import json
import uuid
from urllib import request as urlrequest
from urllib import error as urlerror

LITELLM_BASE = os.getenv("LITELLM_BASE", "http://litellm:4000/v1").rstrip("/")
LITELLM_MASTER_KEY = os.getenv("LITELLM_MASTER_KEY", "")
QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333").rstrip("/")
QDRANT_COLL = os.getenv("QDRANT_COLL", "mem_long")
EMBED_MODEL = os.getenv("EMBED_MODEL", "embed.local")

EMBED_URL = f"{LITELLM_BASE}/embeddings"
QDRANT_COLLECTION_URL = f"{QDRANT_URL}/collections/{QDRANT_COLL}"
QDRANT_UPSERT_URL = f"{QDRANT_COLLECTION_URL}/points"

def _http_request_json(method, url, payload=None, headers=None, timeout=60):
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    req_headers = {"Content-Type": "application/json"}
    if headers:
        req_headers.update(headers)
    req = urlrequest.Request(url, data=data, headers=req_headers, method=method)
    with urlrequest.urlopen(req, timeout=timeout) as resp:
        charset = resp.headers.get_content_charset() or "utf-8"
        body = resp.read().decode(charset)
        if not body:
            return {}
        return json.loads(body)

def _ensure_collection(size=384, distance="Cosine", timeout=10):
    # Check if collection exists
    try:
        _http_request_json("GET", QDRANT_COLLECTION_URL, timeout=timeout)
        return
    except urlerror.HTTPError as e:
        if e.code != 404:
            raise
    # Create collection with HNSW on-disk enabled
    body = {
        "vectors": {"size": int(size), "distance": str(distance)},
        "hnsw_config": {"on_disk": True}
    }
    _http_request_json("PUT", QDRANT_COLLECTION_URL, payload=body, timeout=timeout)

def _embed(text, timeout=30):
    headers = {}
    if LITELLM_MASTER_KEY:
        headers["Authorization"] = f"Bearer {LITELLM_MASTER_KEY}"
    body = {"model": EMBED_MODEL, "input": text}
    resp = _http_request_json("POST", EMBED_URL, payload=body, headers=headers, timeout=timeout)
    vec = resp.get("data", [{}])[0].get("embedding", [])
    if not isinstance(vec, list) or not vec:
        raise RuntimeError("Failed to obtain embedding vector")
    return vec

def _upsert(vector, text, timeout=30):
    point_id = str(uuid.uuid4())
    body = {
        "points": [
            {"id": point_id, "vector": vector, "payload": {"text": text}}
        ]
    }
    _http_request_json("PUT", QDRANT_UPSERT_URL, payload=body, timeout=timeout)
    return point_id

def main(argv):
    if len(argv) < 2:
        print("usage: MEM_CLI.py \"text\" | MEM_CLI.py -  (read from stdin)", file=sys.stderr)
        return 2
    if argv[1] == "-":
        text = sys.stdin.read()
    else:
        text = argv[1]
    text = text.strip()
    if not text:
        print("error: empty text", file=sys.stderr)
        return 2

    try:
        _ensure_collection(size=384, distance="Cosine", timeout=15)
        vec = _embed(text, timeout=30)
        pid = _upsert(vec, text, timeout=30)
        print(pid)
        return 0
    except urlerror.HTTPError as e:
        try:
            details = e.read().decode("utf-8")
        except Exception:
            details = str(e)
        print(f"http_error: {e.code} {details}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

