# PURPOSE: emitir decisão com base nas evidências coletadas pelos P01–P09.

## 1 THINK
Entradas: HEALTH fix status; :4001 up; LOCAL_OK/FB_OK/BACK_OK; BENCH_BAD.

## 2 PLAN
Mapear CREI: Confiabilidade, Risco, Eficiência, Integração.

## 3 CONFIABILIDADE
- :4000 AUTH 200 ?
- health=healthy ?
- :4001 models presentes ?

## 4 RISCO
- Orphans presentes ?
- Keys válidas ?

## 5 EFICIÊNCIA
- BENCH_BAD=0 ?

## 6 INTEGRAÇÃO
- OpenWebUI mapeado p/ :4001 ?

## 7 DECISÃO
- Aprovar | Aprovar c/ ressalvas | Rejeitar híbrido.

## 8 EVIDÊNCIAS
- Cite linhas exatas dos comandos anteriores.

## 9 SAÍDA
- Imprimir DECISION=... com bullets.

## 10 STOP
- Nenhuma ação adicional.
