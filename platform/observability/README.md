# Plataforma de Observabilidad (P4)

> Manifiestos de plataforma para la pila de observabilidad (Prometheus, Grafana, Alertmanager) integrados con External Secrets y Azure Key Vault.

---

## 1. Secretos Administrados
* **`external-secret-grafana.yaml`:** Sincroniza las credenciales de administración de Grafana (`grafana-admin-user`, `grafana-admin-password`) desde Azure Key Vault hacia el Kubernetes Secret `grafana-admin-credentials` en el namespace `monitoring`.

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
