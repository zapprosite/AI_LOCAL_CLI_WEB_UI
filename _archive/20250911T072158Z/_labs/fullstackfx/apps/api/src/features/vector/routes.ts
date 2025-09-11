import { FastifyInstance } from "fastify";
import { config } from "../../config.js";

export async function registerVectorRoutes(app: FastifyInstance) {
  app.get("/ready", async () => {
    try {
      const r = await fetch(`${config.qdrant}/readyz`);
      return { ok: r.ok };
    } catch {
      return { ok: false };
    }
  });
}
