# Componentes de Plataforma (`platform/`)

Este directorio separa los componentes transversales de infraestructura de las aplicaciones de negocio:

* **`gateway/`:** Configuración de Gateway API para enrutamiento L7 y exposición de servicios (P3-04).
* **`cert-manager/`:** Gestión automatizada del ciclo de vida de certificados TLS (P3-04).
* **`external-secrets/`:** Sincronización declarativa de secretos desde Azure Key Vault mediante Azure Workload Identity (P3-05).
* **`argo-rollouts/`:** Controlador y CRDs para despliegues progresivos (Canary / Blue-Green) y análisis métrico automatizado (P3-06).
