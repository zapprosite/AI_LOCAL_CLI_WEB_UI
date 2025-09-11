#!/usr/bin/env python3
import os, sys, json, argparse
from typing import TypedDict, List, Dict, Any, Optional
import httpx
from pydantic import BaseModel, Field, field_validator
from langgraph.graph import StateGraph, END

QDRANT_URL = os.getenv("QDRANT_URL", "http://127.0.0.1:6333")
CODEKB_COLLECTION = os.getenv("CODEKB_COLLECTION", "codekb")
LITELLM_URL = os.getenv("LITELLM_URL", "http://127.0.0.1:4000") + "/v1"
API_KEY = os.getenv("OPENAI_API_KEY", "")

class CliArgs(BaseModel):
  mode: str = Field(pattern="^(chat|docs)$")
  q: str
  @field_validator("q")
  @classmethod
  def non_empty(cls, v: str) -> str:
    v = v.strip()
    if not v: raise ValueError("query must be non-empty")
    return v

class AgentState(TypedDict, total=False):
  question: str; mode: str; model: str; chosen_model: str
  snippets: List[Dict[str,str]]; plan: List[str]; answer: str
  confidence: float; errors: List[str]

def _tok(s: str)->List[str]:
  out, cur = [], []
  for ch in s.lower():
    if ch.isalnum(): cur.append(ch)
    elif cur: out.append("".join(cur)); cur=[]
  if cur: out.append("".join(cur)); return out

def _score(q: str, t: str)->float:
  qt, tt = set(_tok(q)), _tok(t)
  if not tt: return 0.0
  tf: Dict[str,int] = {}
  for w in tt: tf[w]=tf.get(w,0)+1
  return sum((1.0+tf.get(w,0)*0.25) for w in qt if w in tf)

def _payload_text(p: Dict[str,Any])->str:
  for k in ("text","snippet","content","body","code"): 
    if k in p and isinstance(p[k], str): return p[k]
  return str({k:v for k,v in p.items() if isinstance(v,(str,int,float))})[:2000]

def _payload_path(p: Dict[str,Any], d: str)->str:
  for k in ("path","file","source","uri","name"):
    if k in p and isinstance(p[k],str): return p[k]
  return d

def retrieve(state: AgentState)->Dict[str,Any]:
  q, coll = state["question"], CODEKB_COLLECTION
  results: List[Dict[str,str]] = []
  try:
    r = httpx.post(f"{QDRANT_URL}/collections/{coll}/points/scroll",
                   json={"limit":200,"with_payload":True}, timeout=20.0)
    pts = r.json().get("result",{}).get("points",[]) if r.status_code==200 else []
    ranked=[]
    for it in pts:
      pay = it.get("payload",{}) or {}
      txt = _payload_text(pay); 
      if not txt: continue
      ranked.append((_score(q,txt),{"path":_payload_path(pay,str(it.get("id",""))),"snippet":txt[:1200]}))
    ranked.sort(key=lambda x:x[0], reverse=True)
    results = [r for _,r in ranked[:3]]
  except Exception:
    results=[]
  return {"snippets": results}

def plan(state: AgentState)->Dict[str,Any]:
  base=["Clarify intent","Map requirements","Use context","Draft answer","Validate edge cases","Summarize"]
  return {"plan": base}

def _chat(msgs: List[Dict[str,str]], model: str)->str:
  headers={"Content-Type":"application/json"}; 
  if API_KEY: headers["Authorization"]=f"Bearer {API_KEY}"
  r=httpx.post(LITELLM_URL+"/chat/completions",
               json={"model":model,"messages":msgs,"temperature":0.2,"stream":False},
               headers=headers, timeout=20.0)
  r.raise_for_status(); return r.json()["choices"][0]["message"]["content"].strip()

def _compose(state: AgentState)->List[Dict[str,str]]:
  sysmsg="You are a senior engineering assistant. Be correct and concise."
  ctx=[]
  for i,s in enumerate(state.get("snippets",[])[:3],1):
    ctx.append(f"{i}) {s.get('path','')}\n{(s.get('snippet') or '')[:800]}")
  user=f"Mode: {state['mode']}\nQuestion:\n{state['question']}\n\nContext:\n" + ("\n\n".join(ctx) if ctx else "(none)")
  return [{"role":"system","content":sysmsg},{"role":"user","content":user}]

def generate(state: AgentState)->Dict[str,Any]:
  try:
    ans=_chat(_compose(state), state["model"])
    return {"answer":ans,"chosen_model":state["model"],"errors":[]}
  except Exception as e:
    return {"answer":"","chosen_model":state["model"],"errors":[str(e)[:200]]}

def _conf(q:str,a:str,errs:List[str])->float:
  if not a: return 0.0
  c=0.6 if len(a)>=200 else 0.45 if len(a)>=80 else 0.25
  if errs: c-=0.2
  return max(0.0,min(1.0,c))

def verify(state: AgentState)->Dict[str,Any]:
  q,a = state.get("question",""), state.get("answer","")
  errs = state.get("errors",[]) or []
  c=_conf(q,a,errs)
  if c>=0.55 and not errs: return {"confidence":c}
  best=(c,a,state.get("chosen_model",state["model"]))
  for m in ["remote-gpt-5-high","remote-gpt-4o"]:
    try:
      ans=_chat(_compose(state), m); c2=_conf(q,ans,[])
      if c2>best[0]: best=(c2,ans,m)
      if c2>=0.6: break
    except Exception as e: errs.append(str(e)[:200])
  return {"answer":best[1],"chosen_model":best[2],"confidence":best[0],"errors":errs}

def build():
  g=StateGraph(AgentState)
  g.add_node("retrieve", retrieve)
  g.add_node("plan", plan)
  g.add_node("generate", generate)
  g.add_node("verify", verify)
  g.set_entry_point("retrieve")
  g.add_edge("retrieve","plan")
  g.add_edge("plan","generate")
  g.add_edge("generate","verify")
  g.add_edge("verify", END)
  return g.compile()

def main(argv: Optional[List[str]]=None)->int:
  p=argparse.ArgumentParser()
  p.add_argument("--mode",required=True,choices=["chat","docs"])
  p.add_argument("--q",required=True)
  ns=p.parse_args(argv)
  args=CliArgs(mode=ns.mode, q=ns.q)
  model="task:code-router" if args.mode=="chat" else "task:docs-router"
  state: AgentState={"question":args.q,"mode":args.mode,"model":model,
                     "snippets":[], "plan":[], "answer":"", "confidence":0.0, "errors":[]}
  try:
    final=build().invoke(state) # type: ignore
  except Exception as e:
    sys.stderr.write(f"RUNTIME_ERROR:{type(e).__name__}:{str(e)[:200]}\n"); return 1
  print(f"MODEL: {final.get('chosen_model',model)}")
  print("ANSWER:"); print(final.get("answer","").strip())
  print("\nRETRIEVED:")
  sn=final.get("snippets",[]) or []
  if not sn: print("- (none)")
  else:
    for s in sn:
      print(f"- {s.get('path','')}: {(s.get('snippet','') or '').replace(chr(10),' ')[:300]}")
  return 0

if __name__=="__main__": sys.exit(main())
