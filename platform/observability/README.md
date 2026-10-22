# Plataforma de Observabilidad (P4)

> Manifiestos de plataforma para la pila de observabilidad (Prometheus, Grafana, Alertmanager) integrados con External Secrets y Azure Key Vault.

---

## 1. Secretos Administrados
* **`external-secret-grafana.yaml`:** Sincroniza las credenciales de administración de Grafana (`grafana-admin-user`, `grafana-admin-password`) desde Azure Key Vault hacia el Kubernetes Secret `grafana-admin-credentials` en el namespace `monitoring`.
* **`external-secret-discord.yaml`:** Sincroniza la URL del Webhook de Discord (`discord-webhook-url`) desde Azure Key Vault hacia el Kubernetes Secret `alertmanager-discord-webhook` (`webhook-url`) en el namespace `monitoring`.

---

## 2. Aprovisionamiento Automático de Datasources
Mediante la etiqueta `grafana_datasource: "1"`, el sidecar de Grafana detecta y aprovisiona dinámicamente los orígenes de datos:
* **`loki-datasource.yaml`:** Configura Grafana Loki (`http://loki.monitoring.svc:3100`) con `derivedFields` para vincular automáticamente el `trace_id` de logs hacia Grafana Tempo.
* **`tempo-datasource.yaml`:** Configura Grafana Tempo (`http://tempo.monitoring.svc:3200`) con correlación bidireccional:
  * `tracesToLogsV2`: Permite saltar desde cualquier span hacia los logs asociados en Loki.
  * `tracesToMetrics`: Permite saltar desde un span hacia las métricas de latencia y tasa de peticiones en Prometheus.
  * `nodeGraph`: Visualización interactiva del grafo de dependencias entre servicios.

---

## 3. Aprovisionamiento Declarativo de Dashboards (Sidecar Pattern)
Mediante la etiqueta `grafana_dashboard: "1"`, el sidecar de Grafana carga automáticamente los tableros JSON como código:
* **`dashboard-services-red.yaml`:** Tablero basado en el **Método RED** (Rate, Errors, Duration) para Online Boutique con selector dinámico de microservicio (`$service`).
* **`dashboard-nodes-use.yaml`:** Tablero basado en el **Método USE** (Utilization, Saturation, Errors) para los nodos del clúster con selector dinámico (`$node`).
* **Resiliencia:** Si Grafana es borrado o reiniciado, los tableros se reimportan de forma totalmente desatendida.

---

## 4. Reglas de Alerta SRE y Enrutamiento a Discord (P4-05)
* **`prometheus-rules.yaml` (`PrometheusRule`):** Define reglas de alerta orientadas a síntomas (`FrontendHighErrorRate`, `FrontendHighLatencyP95`, `OnlineBoutiqueServiceUnavailable`) y a causas (`PodCrashLooping`, `PodNotReady`, `NodeMemoryPressure`, `NodeHighCPUUtilization`), cada una enriquecida con su respectiva anotación `runbook_url`.
* **`alertmanager-config.yaml` (`AlertmanagerConfig`):** Configura agrupación (`groupBy`), inhibición (`critical` inhibe `warning`) y receptor nativo `discordConfigs` consumiendo el secreto `alertmanager-discord-webhook` con notificaciones de disparo (`FIRING`) y resolución (`RESOLVED`).

---

## 5. Correlación Métricas ➔ Trazas ➔ Logs (P4-06)
* **Prometheus Exemplars (`app-kube-prometheus-stack.yaml`):** Se habilita `enableFeatures: [exemplar-storage]` y `exemplarTraceIdDestinations` (`datasourceUid: tempo`, `traceIdLabelName: trace_id`) en el sidecar de datasources de Grafana.
* **OpenTelemetry Spanmetrics (`app-opentelemetry-collector.yaml`):** El conector `spanmetrics` con `exemplars.enabled: true` y `enable_open_metrics: true` genera histogramas de latencia con `trace_id` directamente desde los spans OTLP.
* **Dashboard RED (`dashboard-services-red.yaml`):** El panel de latencia HTTP activa `"exemplar": true` y Data Links hacia Grafana Tempo y Grafana Loki.
