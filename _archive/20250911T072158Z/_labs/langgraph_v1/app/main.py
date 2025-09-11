from fastapi import FastAPI
from typing import Dict, Any
from langgraph.graph import StateGraph, END
from langchain_core.messages import HumanMessage
from langchain_openai import ChatOpenAI
from qdrant_client import QdrantClient
import os

LITELLM_BASE = os.environ.get("LITELLM_BASE", "http://127.0.0.1:4000")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "x")

llm_code = ChatOpenAI(model="task:code-router", openai_api_base=LITELLM_BASE, api_key=OPENAI_API_KEY)
llm_docs = ChatOpenAI(model="task:docs-router", openai_api_base=LITELLM_BASE, api_key=OPENAI_API_KEY)

# ---- Graph CODE ----
def code_node(state: Dict[str, Any]) -> Dict[str, Any]:
    prompt = state.get("input", "")
    out = llm_code.invoke([HumanMessage(content=prompt)])
    return {"output": out.content}

code_graph = StateGraph(dict)
code_graph.add_node("code", code_node)
code_graph.set_entry_point("code")
code_graph.add_edge("code", END)
code_app = code_graph.compile()

# ---- Graph DOCS/PRD ----
QDRANT_URL = os.environ.get("QDRANT_URL", "http://127.0.0.1:6333")
COLL = os.environ.get("QDRANT_COLLECTION", "docs_prd")
qdr = QdrantClient(url=QDRANT_URL, prefer_grpc=False)

def docs_node(state: Dict[str, Any]) -> Dict[str, Any]:
    q = state.get("input", "")
    ctx = ""
    try:
        res = qdr.search(collection_name=COLL, query_text=q, limit=4)
        ctx = "\n".join([p.payload.get("text","") for p in res])
    except Exception:
        pass
    msg = f"Contexto:\n{ctx}\n\nPergunta:\n{q}"
    out = llm_docs.invoke([HumanMessage(content=msg)])
    return {"output": out.content}

docs_graph = StateGraph(dict)
docs_graph.add_node("docs", docs_node)
docs_graph.set_entry_point("docs")
docs_graph.add_edge("docs", END)
docs_app = docs_graph.compile()

api = FastAPI()

@api.post("/graph-code/invoke")
def invoke_code(body: Dict[str, Any]):
    return code_app.invoke({"input": body.get("input","")})

@api.post("/graph-docs/invoke")
def invoke_docs(body: Dict[str, Any]):
    return docs_app.invoke({"input": body.get("input","")})
