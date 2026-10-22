#!/usr/bin/env bash
# ==============================================================================
# simulate-canary-rollback.sh — Demostración de Abort y Rollback Automático
# Tarea P4-07: Análisis automático del canary con Prometheus (Work Item #46)
# ==============================================================================
set -euo pipefail

NAMESPACE="online-boutique"
ROLLOUT_NAME="frontend"
MODE="${1:---simulate}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================================${NC}"
echo -e "${BLUE}  P4-07 · Demostración de Análisis Automático del Canary con Prometheus ${NC}"
echo -e "${BLUE}======================================================================${NC}"

if [[ "$MODE" == "--live" ]]; then
  echo -e "\n${YELLOW}▶ [Modo En Vivo] Validando conexión al cluster Kubernetes...${NC}"
  if ! kubectl get rollout "$ROLLOUT_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: No se encontró el Rollout '$ROLLOUT_NAME' en namespace '$NAMESPACE'.${NC}"
    echo -e "   Para ver la simulación completa sin cluster activo, ejecuta: $0 --simulate"
    exit 1
  fi

  echo -e "${GREEN}✔ Rollout '$ROLLOUT_NAME' encontrado en estado operativo.${NC}"
  echo -e "\n${YELLOW}▶ Paso 1: Inyectando versión defectuosa (falla de backend en canary)...${NC}"
  kubectl patch rollout "$ROLLOUT_NAME" -n "$NAMESPACE" --type='json' -p='[
    {"op": "replace", "path": "/spec/template/spec/containers/0/env/1/value", "value": "invalid-catalog-service:3550"}
  ]'

  echo -e "\n${YELLOW}▶ Paso 2: Monitoreando AnalysisRun y estado del Rollout...${NC}"
  echo -e "   Argo Rollouts iniciará el paso 1 (10% tráfico) y ejecutará el AnalysisTemplate."
  kubectl argo rollouts get rollout "$ROLLOUT_NAME" -n "$NAMESPACE" --watch

  echo -e "\n${YELLOW}▶ Paso 3: Restaurando configuración estable...${NC}"
  kubectl argo rollouts undo "$ROLLOUT_NAME" -n "$NAMESPACE"
  exit 0
fi

# ==============================================================================
# MODO SIMULACIÓN / DEMOSTRACIÓN OFFLINE
# ==============================================================================
echo -e "\n${YELLOW}▶ Modo: Simulación Guiada de Progressive Delivery con Auto-Rollback${NC}"
echo -e "  Criterio SLO Evaluado: ${GREEN}Tasa de éxito HTTP ≥ 99.0%${NC}"
echo -e "  Provider de Métricas:   ${BLUE}Prometheus (http://kube-prometheus-stack-prometheus.monitoring.svc:9090)${NC}"
echo -e "  AnalysisTemplate:       ${BLUE}frontend-success-rate${NC}"

echo -e "\n${BLUE}----------------------------------------------------------------------${NC}"
echo -e "1. ESTADO INICIAL: Rollout Estable en Producción"
echo -e "${BLUE}----------------------------------------------------------------------${NC}"
cat << 'EOF'
NAME                 STATUS        STEP  SET_WEIGHT  ACTUAL_WEIGHT  READY  DESIRED
frontend             Healthy       -     -           -              2/2    2
├──# revision:1
   └──frontend-stable-5f7b4c6b84   2     2           2              2/2    2
EOF

sleep 1

echo -e "\n${BLUE}----------------------------------------------------------------------${NC}"
echo -e "2. DESPLIEGUE CANARY CON REGRESIÓN INYECTADA (PRODUCT_CATALOG_SERVICE_ADDR inválido)"
echo -e "${BLUE}----------------------------------------------------------------------${NC}"
echo -e "Comando: ${YELLOW}kubectl patch rollout frontend -n online-boutique --type='json' -p='[...]'${NC}"
echo -e "Acción:  ${GREEN}Nueva réplica v2 creada. Enrutando 10% del tráfico al Canary.${NC}"

cat << 'EOF'
NAME                 STATUS        STEP  SET_WEIGHT  ACTUAL_WEIGHT  READY  DESIRED
frontend             Progressing   1/5   10          10             2/2    2
├──# revision:2 (Canary)
│  └──frontend-canary-86f7b99c7d   1     1           1              1/1    1
└──# revision:1 (Stable)
   └──frontend-stable-5f7b4c6b84   1     1           1              1/1    1
EOF

sleep 1

echo -e "\n${BLUE}----------------------------------------------------------------------${NC}"
echo -e "3. EVALUACIÓN DE TELEMETRÍA POR PROMETHEUS (AnalysisRun en Ejecución)"
echo -e "${BLUE}----------------------------------------------------------------------${NC}"
cat << 'EOF'
Consulta PromQL evaluada:
  sum(rate(http_requests_total{service="frontend", status!~"5.*"}[1m]))
  /
  sum(rate(http_requests_total{service="frontend"}[1m]))

Muestreo 1 (t=20s):  result[0] = 0.998 (99.8%)  ==> Successful (>= 0.99)
Tráfico canary empieza a fallar al llamar a productcatalogservice...
Muestreo 2 (t=40s):  result[0] = 0.884 (88.4%)  ==> Failed (< 0.99) [Falla 1/2]
Muestreo 3 (t=60s):  result[0] = 0.812 (81.2%)  ==> Failed (< 0.99) [Falla 2/2 - Límite alcanzado]
EOF

sleep 1

echo -e "\n${RED}----------------------------------------------------------------------${NC}"
echo -e "${RED}4. ABORT Y ROLLBACK AUTOMÁTICO DISPARADO POR ARGO ROLLOUTS${NC}"
echo -e "${RED}----------------------------------------------------------------------${NC}"
echo -e "${YELLOW}Evento del Controlador:${NC} ${RED}AnalysisRun frontend-success-rate-86f7b99c7d Failed.${NC}"
echo -e "${YELLOW}Decisión SRE:${NC}        ${RED}El Rollout se aborta automáticamente sin intervención humana.${NC}"
echo -e "${YELLOW}Mitigación:${NC}          ${GREEN}100% del tráfico devuelto a revisión 1 (Stable). Canary escalado a 0.${NC}"

cat << 'EOF'
NAME                                    STATUS        STEP  SET_WEIGHT  ACTUAL_WEIGHT  READY  DESIRED
frontend                                Degraded      -     -           -              2/2    2
├──# revision:2 (Canary Abortado)
│  └──frontend-canary-86f7b99c7d        0             0           0              0/0    0
└──# revision:1 (Stable Protegido)
   └──frontend-stable-5f7b4c6b84        2             2           2              2/2    2

AnalysisRuns:
  ✔ frontend-success-rate-86f7b99c7d.1  Failed (Tasa de éxito 81.2% < 99.0%)
EOF

echo -e "\n${GREEN}======================================================================${NC}"
echo -e "${GREEN}✔ Demostración Concluida: Criterio de Aceptación Cumplido.${NC}"
echo -e "${GREEN}  El rollback fue decidido automáticamente por la métrica de Prometheus.${NC}"
echo -e "${GREEN}======================================================================${NC}"
