# ADR 004: Entrega Progresiva (Canary Releases) con Argo Rollouts vs. Deployment Estándar

* **Estado:** Aceptado
* **Fecha:** 2026-10-08
* **Decisores:** Equipo DevOps & SRE
* **Contexto:** Tarea P3-06 (Work Item #37) — Proyecto 3 (`platform-gitops`)

---

## 1. Contexto y Problema

El microservicio `frontend` es la cara pública y punto de entrada para todos los usuarios de **Online Boutique**. Un despliegue defectuoso que introduzca errores 5xx o latencias elevadas afectaría al 100% de los usuarios de inmediato si se utiliza una estrategia de actualización en masa.

El recurso nativo `Deployment` de Kubernetes sólo ofrece dos estrategias:
1. `Recreate`: Genera tiempo de inactividad (*downtime*).
2. `RollingUpdate`: Reemplaza pods gradualmente, pero no ofrece control fino sobre porcentajes de tráfico, pausas para verificación ni rollback automático basado en métricas.

---

## 2. Decisión

Reemplazar el `Deployment` del frontend por el recurso de CRD **`Rollout` de Argo Rollouts**, implementando una estrategia **Canary Release** por pasos con división de tráfico y plantillas de análisis automatizadas (`AnalysisTemplate`).

---

## 3. Justificación y Análisis Comparativo

| Criterio de Evaluación | Kubernetes Deployment (`RollingUpdate`) | Argo Rollouts (`Canary Release`) [Elegido] |
| :--- | :--- | :--- |
| **Blast Radius de Fallos** | Alto: el 100% de los usuarios reciben la nueva versión en minutos. | Mínimo: la nueva versión se expone inicialmente al 10%, luego 50% y finalmente 100%. |
| **Pausas y Verificación Humana/Sintética** | No permite pausas controladas ni etapas de observación entre réplicas. | Pausas declarativas (`pause: {duration: 1m}`) para validar telemetría y smoke tests. |
| **Rollback y Abort** | Requiere revertir el commit o ejecutar `kubectl rollout undo` manualmente tras el impacto. | Abort instantáneo (`kubectl argo rollouts abort`) que desvía el 100% del tráfico a la versión previa de inmediato. |
| **Análisis Automatizado de Métricas** | Inexistente: no se integra con Prometheus ni evalúa métricas SLO. | `AnalysisTemplate` ejecuta consultas periódicas a Prometheus y aborta si se violan los umbrales de error o latencia. |
| **Operabilidad con CLI** | `kubectl rollout` básico. | Plugin dedicado `kubectl-argo-rollouts` con vista interactiva en tiempo real y comandos de control fino. |

---

## 4. Consecuencias

* El frontend utiliza `kind: Rollout` tanto en `base` como en los parches de `overlays/dev` y `overlays/prod`.
* Se crean dos servicios independientes: `frontend` (estable) y `frontend-canary` (versión en evaluación).
* La promoción automática de imágenes en CI/CD (`kustomize edit set image`) continúa operando de forma transparente sobre la especificación del Rollout.
* Se habilitan las bases para el análisis automático de métricas SLO con Prometheus en P4-07.
