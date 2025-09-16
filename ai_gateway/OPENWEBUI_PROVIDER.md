# OpenWebUI Provider (Fallback Router)

Use this to point OpenWebUI at the fallback router service (`litellm_fb`).

## Provider Setup
- Provider: OpenAI
- Base URL: `http://litellm_fb:4000/v1`
- API Key: `${LITELLM_MASTER_KEY}` (from `ai_gateway/.env`)

Save the provider, then in the chat view select one of the router aliases below.

## Models to Select
- `code.router`
- `docs.router`
- `search.router`

## Triggering Fallback
Fallback to the OpenAI backend is enabled when `metadata.high_stakes` is set to `true` on a request. In OpenWebUI, add this JSON in the Advanced headers/params field so it is included with the request body:

```json
{
  "metadata": { "high_stakes": true }
}
```

When engaged, responses will indicate the backend model as `openai/gpt-5`.

