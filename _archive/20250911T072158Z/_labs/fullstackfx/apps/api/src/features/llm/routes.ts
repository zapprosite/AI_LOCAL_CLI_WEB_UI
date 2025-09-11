import { FastifyInstance } from "fastify";
import { config } from "../../config.js";

export async function registerLlmRoutes(app: FastifyInstance) {
  app.get("/models", async (req, reply) => {
    try {
      const r = await fetch(`${config.liteLLM}/models`);
      if (r.ok) return r.json();
    } catch {}
    if (!config.openaiKey) {
      return reply.code(502).send({ error: "LiteLLM is down and OPENAI_API_KEY is not set" });
    }
    const r2 = await fetch(`${config.openaiBase}/models`, {
      headers: { Authorization: `Bearer ${config.openaiKey}` }
    });
    return r2.json();
  });
}
