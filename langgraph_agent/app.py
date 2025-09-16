#!/usr/bin/env python3
"""
Minimal RAG-aware HTTP server for LiteLLM routers using only Python stdlib.

- POST /code   -> chat via model "code.router"
- POST /docs   -> chat via model "docs.router"
- POST /search -> chat via model "search.router"

RAG flow:
- Embed query using LiteLLM /embeddings with EMBED_MODEL (default: embed.local)
- Vector search on Qdrant: POST /collections/${QDRANT_COLL}/points/search
- Build a context string from top results and prepend as a system message

Env:
- LITELLM_BASE (default: http://litellm:4000/v1)
- LITELLM_MASTER_KEY (optional for Authorization: Bearer)
- QDRANT_URL (default: http://qdrant:6333)
- QDRANT_COLL (default: mem_long)
- EMBED_MODEL (default: embed.local)
- PORT (default: 9099)
"""
import os
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib import request as urlrequest
from urllib import error as urlerror

# Environment
LITELLM_BASE = os.getenv("LITELLM_BASE", "http://litellm:4000/v1").rstrip("/")
LITELLM_MASTER_KEY = os.getenv("LITELLM_MASTER_KEY", "")
QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333").rstrip("/")
QDRANT_COLL = os.getenv("QDRANT_COLL", "mem_long")
EMBED_MODEL = os.getenv("EMBED_MODEL", "embed.local")
PORT = int(os.getenv("PORT", "9099"))

# Endpoints
EMBED_URL = f"{LITELLM_BASE}/embeddings"
CHAT_URL = f"{LITELLM_BASE}/chat/completions"
QDRANT_SEARCH_URL = f"{QDRANT_URL}/collections/{QDRANT_COLL}/points/search"

# Router mappings
ROUTES = {
    "/code": "code.router",
    "/docs": "docs.router",
    "/search": "search.router",
}

def _http_post_json(url, payload, headers=None, timeout=60):
    data = json.dumps(payload).encode("utf-8")
    req_headers = {"Content-Type": "application/json"}
    if headers:
        req_headers.update(headers)
    req = urlrequest.Request(url, data=data, headers=req_headers, method="POST")
    with urlrequest.urlopen(req, timeout=timeout) as resp:
        charset = resp.headers.get_content_charset() or "utf-8"
        body = resp.read().decode(charset)
        return json.loads(body)

def _embed_query(text, timeout=30):
    headers = {}
    if LITELLM_MASTER_KEY:
        headers["Authorization"] = f"Bearer {LITELLM_MASTER_KEY}"
    payload = {
        "model": EMBED_MODEL,
        "input": text,
    }
    resp = _http_post_json(EMBED_URL, payload, headers=headers, timeout=timeout)
    # OpenAI-style embeddings response
    vec = resp.get("data", [{}])[0].get("embedding", [])
    if not isinstance(vec, list) or not vec:
        raise ValueError("Embedding vector not found or empty")
    return vec

def _qdrant_search(vector, limit=5, timeout=30):
    payload = {
        "vector": vector,
        "limit": int(limit),
        "with_payload": True,
    }
    # Qdrant typically doesn't require auth in local dev
    resp = _http_post_json(QDRANT_SEARCH_URL, payload, headers=None, timeout=timeout)
    return resp.get("result", []) or []

def _extract_text_from_payload(payload):
    # Try common payload fields for text
    for key in ("text", "content", "page_content", "chunk", "body"):
        if isinstance(payload, dict) and key in payload:
            val = payload.get(key)
            if isinstance(val, str):
                return val
    # Fallback to JSON-compact payload
    try:
        return json.dumps(payload, ensure_ascii=False)
    except Exception:
        return str(payload)

def _build_context_from_points(points):
    if not points:
        return "", []
    lines = []
    sources = []
    for idx, p in enumerate(points, start=1):
        payload = p.get("payload", {})
        score = p.get("score")
        text = _extract_text_from_payload(payload)
        lines.append(f"[{idx}] score={score}\n{text}")
        sources.append({
            "index": idx,
            "id": p.get("id"),
            "score": score,
            "text_preview": text[:300] if isinstance(text, str) else "",
        })
    context = "Context documents:\n" + "\n\n".join(lines)
    return context, sources

def _chat_with_router(router_model, messages, extra=None, timeout=65):
    headers = {}
    if LITELLM_MASTER_KEY:
        headers["Authorization"] = f"Bearer {LITELLM_MASTER_KEY}"
    payload = {
        "model": router_model,
        "messages": messages,
    }
    if isinstance(extra, dict):
        # Pass through optional fields (e.g., temperature, max_tokens, metadata)
        for k, v in extra.items():
            if k not in payload:
                payload[k] = v
    return _http_post_json(CHAT_URL, payload, headers=headers, timeout=timeout)

class Handler(BaseHTTPRequestHandler):
    server_version = "LangGraphAgentStdlib/0.1"

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8")
        if not raw:
            return {}
        try:
            return json.loads(raw)
        except Exception as e:
            raise ValueError(f"Invalid JSON: {e}")

    def _send_json(self, code, obj):
        out = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def do_POST(self):
        router_model = ROUTES.get(self.path)
        if not router_model:
            self._send_json(404, {"error": f"unknown path {self.path}"})
            return

        try:
            body = self._read_json()
        except ValueError as e:
            self._send_json(400, {"error": str(e)})
            return

        # Accept either "query" or a full "messages" array (OpenAI style).
        query = None
        messages = None
        if isinstance(body.get("messages"), list):
            messages = body["messages"]
            # If no explicit query provided, try to infer from last user message
            for m in reversed(messages):
                if isinstance(m, dict) and m.get("role") == "user" and isinstance(m.get("content"), str):
                    query = m["content"]
                    break
        if not query and isinstance(body.get("query"), str):
            query = body["query"]

        if not query and not messages:
            self._send_json(400, {"error": "expected 'query' string or 'messages' array"})
            return

        top_k = body.get("top_k", 5)

        # RAG: embed and search Qdrant; on failure proceed without context
        context = ""
        sources = []
        try:
            emb = _embed_query(query or "")
            points = _qdrant_search(emb, limit=top_k)
            context, sources = _build_context_from_points(points)
        except Exception as e:
            context = ""
            sources = []
            # Non-fatal: continue to chat without context
            # You can inspect server logs for the underlying error
            print(f"[warn] RAG context failed: {e}")

        final_messages = []
        if context:
            final_messages.append({
                "role": "system",
                "content": "Use the following context if relevant to answer the user:\n\n" + context
            })
        if messages:
            final_messages.extend(messages)
        else:
            final_messages.append({"role": "user", "content": query})

        # Allow passthrough of optional chat params, excluding reserved keys
        passthrough = {}
        for k in ("temperature", "max_tokens", "metadata", "top_p", "frequency_penalty", "presence_penalty", "stream"):
            if k in body:
                passthrough[k] = body[k]

        try:
            chat_resp = _chat_with_router(router_model, final_messages, extra=passthrough)
        except urlerror.HTTPError as e:
            try:
                err_txt = e.read().decode("utf-8")
            except Exception:
                err_txt = str(e)
            self._send_json(e.code, {"error": "chat_http_error", "details": err_txt})
            return
        except Exception as e:
            self._send_json(502, {"error": "chat_failed", "details": str(e)})
            return

        result = {
            "ok": True,
            "model": router_model,
            "rag": {
                "sources_count": len(sources),
                "sources": sources,
                "context_included": bool(context),
            },
            "response": chat_resp,
        }
        self._send_json(200, result)

    # Reduce default noisy logging
    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args))

def main():
    addr = ("0.0.0.0", PORT)
    httpd = HTTPServer(addr, Handler)
    print(f"Listening on http://{addr[0]}:{addr[1]}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()

if __name__ == "__main__":
    main()

