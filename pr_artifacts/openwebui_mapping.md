# OpenWebUI: LiteLLM FB Router Mappings (port 4001)

Use this checklist to wire OpenWebUI to the LiteLLM fallback proxy without changing base files.

- Provider
  - Type: OpenAI-compatible (Custom/OpenAI API)
  - Base URL: `http://localhost:4001`
  - API Key: `${LITELLM_MASTER_KEY}`
  - Notes: OpenWebUI appends `/v1` automatically for OpenAI-compatible providers.

- Models to use
  - Local-only (direct to Ollama): `code.router`, `docs.router`, `search.router`
  - Hybrid with fallback (routes to OpenAI on failure/high stakes): `code.hybrid`, `docs.hybrid`, `search.hybrid`

- System presets (recommended)
  - Code (router)
    - Model: `code.router`
    - System: "You are a precise coding assistant. Return minimal, compilable answers. Prefer short code blocks and no extra prose unless asked."
    - Temperature: `0`
  - Code (hybrid)
    - Model: `code.hybrid`
    - System: "You are a precise coding assistant. If the task is high risk or safety-critical, be extra conservative and explicit."
    - Temperature: `0`
  - Docs (router/hybrid)
    - Model: `docs.router` or `docs.hybrid`
    - System: "Summarize and clarify documentation succinctly. Prefer bullets, include key steps and any important caveats."
    - Temperature: `0.2`
  - Search (router/hybrid)
    - Model: `search.router` or `search.hybrid`
    - System: "Answer briefly with the most relevant facts. Provide 1–2 sentences and up to 3 keywords for follow‑up."
    - Temperature: `0.2`

- Quick verify
  - Models: In a new chat, pick provider above, then select one of the listed model ids; send `"ping"` and expect a short response.
  - Deterministic math (code): Model `code.hybrid`, prompt `"2+2? answer with a single digit"` → content `4` and model starting with `ollama/qwen2.5-coder`.
  - Fallback (optional): Temporarily stop or block local Ollama; with `metadata.high_stakes=true` expect model to switch to `openai/gpt-5`.
