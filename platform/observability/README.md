# Plataforma de Observabilidad (P4)

> Manifiestos de plataforma para la pila de observabilidad (Prometheus, Grafana, Alertmanager) integrados con External Secrets y Azure Key Vault.

---

## 1. Secretos Administrados
* **`external-secret-grafana.yaml`:** Sincroniza las credenciales de administración de Grafana (`grafana-admin-user`, `grafana-admin-password`) desde Azure Key Vault hacia el Kubernetes Secret `grafana-admin-credentials` en el namespace `monitoring`.
