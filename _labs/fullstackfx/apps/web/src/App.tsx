import React, { useEffect, useRef, useState } from "react";
type User = { id: number; name: string; email: string };
type Log = { t: number; msg: string };

export default function App() {
  const api = import.meta.env.VITE_API_URL || "http://localhost:3300";

  const [users, setUsers] = useState<User[]>([]);
  useEffect(() => { fetch(`${api}/api/users`).then(r=>r.json()).then(setUsers).catch(console.error); }, [api]);

  const [sseLogs, setSseLogs] = useState<Log[]>([]);
  const sseRef = useRef<EventSource | null>(null);
  const startSSE = () => {
    if (sseRef.current) return;
    const es = new EventSource(`${api}/api/stream/sse`);
    sseRef.current = es;
    es.onmessage = (ev) => {
      try { const d = JSON.parse(ev.data); setSseLogs(p=>[...p,{t:Date.now(),msg:JSON.stringify(d)}]); }
      catch { setSseLogs(p=>[...p,{t:Date.now(),msg:ev.data}]); }
    };
    es.onerror = () => { stopSSE(); };
  };
  const stopSSE = () => { sseRef.current?.close(); sseRef.current = null; };

  const [tokens, setTokens] = useState<string>("");
  const runTokens = () => {
    const es = new EventSource(`${api}/api/stream/tokens?text=${encodeURIComponent("hello from sse tokens demo")}`);
    let buf = "";
    es.onmessage = (ev) => {
      try { const d = JSON.parse(ev.data); if (d.token) buf += d.token + " "; if (d.done) es.close(); setTokens(buf); } catch {}
    };
    es.onerror = () => es.close();
  };

  const [chunks, setChunks] = useState<string>("");
  const runChunks = async () => {
    setChunks("");
    const res = await fetch(`${api}/api/stream/chunks?text=${encodeURIComponent("chunked text streaming via fetch reader")}`);
    const reader = res.body?.getReader(); if (!reader) return;
    const dec = new TextDecoder("utf-8");
    while (true) { const { done, value } = await reader.read(); if (done) break; setChunks(prev => prev + dec.decode(value)); }
  };

  return (
    <main style={{ fontFamily:"sans-serif", padding:24, display:"grid", gap:24 }}>
      <section><h1>fullstackfx – Web</h1><p>API: {api}</p></section>
      <section><h2>Users</h2><ul>{users.map(u=>(<li key={u.id}>{u.id} – {u.name} – {u.email}</li>))}</ul></section>
      <section><h2>SSE – /api/stream/sse</h2><div style={{display:"flex",gap:8}}>
        <button onClick={startSSE}>Start SSE</button><button onClick={stopSSE}>Stop SSE</button></div>
        <pre style={{background:"#111",color:"#0f0",padding:12,height:160,overflow:"auto"}}>{JSON.stringify(sseLogs,null,2)}</pre>
      </section>
      <section><h2>Tokens SSE – /api/stream/tokens</h2><button onClick={runTokens}>Run tokens demo</button>
        <pre style={{background:"#111",color:"#0ff",padding:12}}>{tokens}</pre></section>
      <section><h2>Chunked – /api/stream/chunks</h2><button onClick={runChunks}>Run chunked demo</button>
        <pre style={{background:"#111",color:"#fff",padding:12}}>{chunks}</pre></section>
    </main>
  );
}
