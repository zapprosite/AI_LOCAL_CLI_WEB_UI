import { ChatOpenAI } from "@langchain/openai";
const baseUrl = process.env.OPENAI_BASE_URL || process.env.OPENAI_API_BASE || process.env.LITELLM_BASE || "http://127.0.0.1:4000";
const apiKey  = process.env.OPENAI_API_KEY || "x";
const llm = new ChatOpenAI({ model: "task:code-router", baseUrl, apiKey });
const q = process.argv.slice(2).join(" ") || "show nvidia gpus with bash";
const out = await llm.invoke(q);
console.error("[debug] baseUrl=", baseUrl);
console.log(out.content);
