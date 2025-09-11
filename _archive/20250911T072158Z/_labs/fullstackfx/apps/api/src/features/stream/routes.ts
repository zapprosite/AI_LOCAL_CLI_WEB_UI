import { FastifyInstance } from "fastify";
import type { ServerResponse } from "http";

function sseWrite(res: ServerResponse, data: unknown) { res.write(`data: ${JSON.stringify(data)}\n\n`); }
function ssePing(res: ServerResponse) { res.write(`: ping\n\n`); }

export async function registerStreamRoutes(app: FastifyInstance) {
  app.get("/sse", async (req, reply) => {
    reply.raw.setHeader("Content-Type", "text/event-stream; charset=utf-8");
    reply.raw.setHeader("Cache-Control", "no-cache, no-transform");
    reply.raw.setHeader("Connection", "keep-alive");
    (reply.raw as any).flushHeaders?.();

    let i = 0;
    const msg = setInterval(() => { i++; sseWrite(reply.raw, { t: Date.now(), i, msg: `tick-${i}` }); }, 1000);
    const ping = setInterval(() => ssePing(reply.raw), 15000);

    const close = () => { clearInterval(msg); clearInterval(ping); try { reply.raw.end(); } catch {} };
    req.raw.on("close", close); req.raw.on("aborted", close);

    sseWrite(reply.raw, { ready: true });
  });

  app.get("/tokens", async (req, reply) => {
    const url = new URL(req.url, "http://localhost");
    const text = url.searchParams.get("text") ?? "streaming tokens sample";
    const toks = text.split(/\s+/).filter(Boolean);

    reply.raw.setHeader("Content-Type", "text/event-stream; charset=utf-8");
    reply.raw.setHeader("Cache-Control", "no-cache, no-transform");
    reply.raw.setHeader("Connection", "keep-alive");
    (reply.raw as any).flushHeaders?.();

    let i = 0;
    const timer = setInterval(() => {
      if (i >= toks.length) { sseWrite(reply.raw, { done: true }); clearInterval(timer); try { reply.raw.end(); } catch {}; return; }
      sseWrite(reply.raw, { token: toks[i++] });
    }, 120);

    const close = () => { clearInterval(timer); try { reply.raw.end(); } catch {} };
    req.raw.on("close", close); req.raw.on("aborted", close);

    sseWrite(reply.raw, { ready: true, total: toks.length });
  });

  app.get("/chunks", async (req, reply) => {
    const url = new URL(req.url, "http://localhost");
    const text = url.searchParams.get("text") ?? "chunked response sample";
    const parts = text.split(/\s+/).filter(Boolean);

    reply.raw.setHeader("Content-Type", "text/plain; charset=utf-8");
    reply.raw.setHeader("Cache-Control", "no-cache, no-transform");
    reply.raw.setHeader("Transfer-Encoding", "chunked");
    (reply.raw as any).flushHeaders?.();

    let i = 0;
    const timer = setInterval(() => {
      if (i >= parts.length) { clearInterval(timer); try { reply.raw.end("\n[done]\n"); } catch {}; return; }
      reply.raw.write(parts[i++] + " ");
    }, 120);

    const close = () => { clearInterval(timer); try { reply.raw.end(); } catch {} };
    req.raw.on("close", close); req.raw.on("aborted", close);

    reply.raw.write("[start] ");
  });
}
