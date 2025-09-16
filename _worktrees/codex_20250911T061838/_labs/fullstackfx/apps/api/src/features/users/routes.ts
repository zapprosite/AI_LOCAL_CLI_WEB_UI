import { FastifyInstance } from "fastify";
import { z } from "zod";
import type { User } from "@fullstackfx/shared";

const users: User[] = [
  { id: 1, name: "Will", email: "will@example.com" },
  { id: 2, name: "Artha", email: "artha@example.com" }
];

export async function registerUserRoutes(app: FastifyInstance) {
  app.get("/", async () => users);

  app.get("/:id", async (req, reply) => {
    const params = z.object({ id: z.coerce.number().int().positive() }).parse(req.params);
    const u = users.find(x => x.id === params.id);
    if (!u) return reply.code(404).send({ error: "User not found" });
    return u;
  });

  app.post("/", async (req, reply) => {
    const body = z.object({ name: z.string().min(1), email: z.string().email() }).parse(req.body);
    const nextId = users.reduce((m, x) => Math.max(m, x.id), 0) + 1;
    const created: User = { id: nextId, ...body };
    users.push(created);
    return reply.code(201).send(created);
  });
}
