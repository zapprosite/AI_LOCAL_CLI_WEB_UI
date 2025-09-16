# PURPOSE: garantir que bench.csv só registra HTTP:200.

## 1 THINK
Linhas com HTTP: !=200 poluem baseline.

## 2 PLAN
awk para contar total e ruins.

## 3 EXEC
if [ -f /data/stack/_logs/bench.csv ]; then
  awk '{ n=match($0,/HTTP:([0-9]{3})/,m); if(n){t++; if(m[1]!=200) b++} } END{ printf "BENCH_TOTAL=%d BENCH_BAD=%d\\n",t,b }' /data/stack/_logs/bench.csv
  tail -n 50 /data/stack/_logs/bench.csv
else
  echo "BENCH=MISSING"
fi

## 4 CLASSIFY
# BENCH_BAD=0 esperado.

## 5 RISK
# Erros indicam instabilidade.

## 6 VERIFY
# Registrar contagem.

## 7 NEXT
# Corrigir scripts se necessário (fora deste prompt).

## 8 END
# Done.

## 9 —
## 10 —
