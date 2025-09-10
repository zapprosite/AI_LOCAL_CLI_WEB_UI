import Fastify from "fastify";
import cors from "@fastify/cors";
import { config } from "./config.js";
import { registerUserRoutes } from "./features/users/routes.js";
import { registerStreamRoutes } from "./features/stream/routes.js";
import { registerLlmRoutes } from "./features/llm/routes.js";
import { registerVectorRoutes } from "./features/vector/routes.js";

const app = Fastify({ logger: true });
await app.register(cors, { origin: true });

app.get("/health", async () => ({ ok: true, service: "api" }));
app.register(registerUserRoutes,  { prefix: "/api/users" });
app.register(registerStreamRoutes,{ prefix: "/api/stream" });
app.register(registerLlmRoutes,   { prefix: "/api/llm" });
app.register(registerVectorRoutes,{ prefix: "/api/vector" });

app.listen({ port: config.port, host: config.host }).catch((err) => {
  app.log.error(err);
  process.exit(1);
});
