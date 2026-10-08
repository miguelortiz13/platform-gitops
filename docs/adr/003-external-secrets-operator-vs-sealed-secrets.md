# ADR 003: External Secrets Operator con Workload Identity vs. Secretos Cifrados en Git

* **Estado:** Aceptado
* **Fecha:** 2026-10-08
* **Decisores:** Equipo DevOps & SRE
* **Contexto:** Tarea P3-05 (Work Item #36) — Proyecto 3 (`platform-gitops`)

---

## 1. Contexto y Problema

Uno de los principios de GitOps es almacenar todo el estado deseado en Git. Sin embargo, los secretos sensibles (claves de bases de datos, tokens de APIs, certificados privados) nunca deben persistirse en texto plano en repositorios de código.

Existen dos filosofías principales para resolver este dilema:
1. **Secretos Cifrados en Git (ej. Bitnami Sealed Secrets, SOPS / Age):** Cifrar los valores sensibles en el repositorio y descifrarlos dentro del clúster con una clave privada maestra.
2. **External Secrets con Identity Federation (ej. External Secrets Operator + Azure Key Vault + Workload Identity):** Mantener Git libre de datos sensibles y sincronizar los secretos en tiempo de ejecución desde un Key Management Service (KMS) administrado.

---

## 2. Decisión

Adoptar **External Secrets Operator (ESO)** con **Azure Workload Identity** apuntando a **Azure Key Vault**, descartando el almacenamiento de secretos cifrados en Git.

---

## 3. Justificación y Análisis Comparativo

| Criterio de Evaluación | Secretos Cifrados en Git (Sealed Secrets / SOPS) | External Secrets Operator + Key Vault [Elegido] |
| :--- | :--- | :--- |
| **Higiene de Seguridad en Git** | Secretos cifrados residen en el historial de Git para siempre (riesgo ante compromiso de clave privada futura). | **Zero Secrets in Git:** Cero valores sensibles o blobs cifrados en Git. |
| **Rotación de Secretos** | Compleja: rotar un secreto requiere regenerar el archivo cifrado, abrir PR, hacer review y mergear en Git. | **Rotación Automática:** Modificar el secreto en Azure Key Vault lo propaga automáticamente al clúster en el intervalo de refresco. |
| **Autenticación y Credenciales** | La clave de descifrado reside en el clúster como un Secret estático. | **Workload Identity OIDC:** Cero credenciales estáticas; intercambio dinámico de tokens federados en memoria del pod. |
| **Gobernanza y Auditoría** | La auditoría depende del log de commits de Git (no audita accesos de lectura reales). | Azure Key Vault logs registra cada acceso con identidad, timestamp e IP en Log Analytics. |
| **Control de Acceso (RBAC)** | Todo el que tenga acceso a la clave privada del clúster puede descifrar todo. | Azure RBAC granular (`Key Vault Secrets User`) por entorno y por identidad administrada. |

---

## 4. Consecuencias

* Git almacena únicamente definiciones declarativas `ClusterSecretStore` y `ExternalSecret` que describen *de dónde* y *qué clave* obtener, no el valor sensible.
* Se elimina por completo el riesgo de fuga de credenciales en Git.
* Se requiere configurar la identidad administrada y la credencial federada en Terraform (`infra-azure-terraform`).
