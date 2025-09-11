import "dotenv/config";
export const config = {
  port: Number(process.env.PORT_API ?? 3300),
  host: process.env.HOST ?? "0.0.0.0",
  liteLLM: process.env.LITELLM_BASE_URL ?? "http://localhost:4000/v1",
  ollama: process.env.OLLAMA_BASE_URL ?? "http://localhost:11434",
  qdrant: process.env.QDRANT_URL ?? "http://localhost:6333",
  openaiBase: process.env.OPENAI_BASE_URL ?? "https://api.openai.com/v1",
  openaiKey: process.env.OPENAI_API_KEY
};
