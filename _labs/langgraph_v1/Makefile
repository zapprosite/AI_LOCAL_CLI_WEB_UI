VENV=.venv

init:
	python3 -m venv $(VENV)
	. $(VENV)/bin/activate; python -m pip install -U pip wheel
	. $(VENV)/bin/activate; python -m pip install -r requirements.txt

run:
	. $(VENV)/bin/activate; LITELLM_BASE=${LITELLM_BASE:-http://127.0.0.1:4000} OPENAI_API_KEY=${OPENAI_API_KEY:-sk-local} uvicorn app.main:api --host 0.0.0.0 --port 8000

test-code:
	curl -sS localhost:8000/graph-code/invoke -H 'content-type: application/json' -d '{"input":"Show a Docker Compose healthcheck for Qdrant"}' | jq .

test-docs:
	curl -sS localhost:8000/graph-docs/invoke -H 'content-type: application/json' -d '{"input":"Resumo de PRD do serviço X"}' | jq .
