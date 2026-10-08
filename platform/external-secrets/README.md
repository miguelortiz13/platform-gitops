# External Secrets Operator (P3-05)

> Sincronización declarativa de secretos desde **Azure Key Vault** hacia Kubernetes Secrets nativos mediante **Azure Workload Identity** (cero secretos estáticos en Git y en el clúster).

---

## 1. Arquitectura y Flujo de Autenticación

El operador **External Secrets Operator (ESO)** desacopla la gestión de secretos del código y los manifiestos, sincronizándolos automáticamente desde Azure Key Vault en tiempo de ejecución.

```mermaid
sequenceDiagram
    autonumber
    participant Git as GitOps Repo (Git)
    participant Argo as Argo CD
    participant ESO as External Secrets Operator
    participant K8sSA as ServiceAccount (external-secrets)
    participant Entra as Microsoft Entra ID (OIDC)
    participant KV as Azure Key Vault
    participant K8sSec as K8s Secret (sample-app-secret)

    Git->>Argo: Sincroniza ClusterSecretStore y ExternalSecret
    Argo->>ESO: Aplica CRDs en el clúster
    ESO->>K8sSA: Solicita projected token (audience: api://AzureADTokenExchange)
    K8sSA-->>ESO: Token firmado por el OIDC Issuer de AKS
    ESO->>Entra: Intercambia token federado por Azure Access Token
    Entra-->>ESO: Retorna Access Token con rol Key Vault Secrets User
    ESO->>KV: Consulta secreto 'db-password-sample'
    KV-->>ESO: Retorna valor del secreto cifrado en tránsito
    ESO->>K8sSec: Crea/actualiza Secret nativo en namespace 'online-boutique'
```

---

## 2. Componentes y Recursos

### 2.1. Infraestructura Base en Azure (Terraform `infra-azure-terraform`)
* **Identidad Administrada (`azurerm_user_assigned_identity.eso`):** `uami-eso-devops-sre-dev-eastus2`.
* **Credencial Federada (`azurerm_federated_identity_credential.eso`):** Vincula la UAMI con el ServiceAccount `system:serviceaccount:external-secrets:external-secrets` utilizando el OIDC Issuer del clúster AKS.
* **Asignación RBAC (`azurerm_role_assignment.eso_kv_secrets_user`):** Asigna el rol `Key Vault Secrets User` en el Key Vault correspondiente.

### 2.2. Despliegue de Helm vía Argo CD (`clusters/dev/app-external-secrets.yaml`)
* Despliega el chart oficial `external-secrets/external-secrets` (v2.12.0) en el namespace `external-secrets` con `installCRDs: true` en Sync Wave 0.

### 2.3. ClusterSecretStore (`cluster-secret-store.yaml`)
* Recurso de ámbito clúster que configura el proveedor `azurekv` con `authType: WorkloadIdentity`, apuntando al endpoint de Key Vault (`https://kv-devops-sre-dev.vault.azure.net`) y referenciando el `serviceAccountRef` de ESO.

### 2.4. ExternalSecret de Prueba (`external-secret-sample.yaml`)
* Define la sincronización del secreto `db-password-sample` desde Key Vault hacia el Secret nativo `sample-app-secret` en el namespace `online-boutique` con un intervalo de refresco de 1 hora (`refreshInterval: 1h`) y política de ownership.

---

## 3. Seguridad y Beneficios
* ✅ **Cero Secretos en Git:** Ningún valor sensible ni contraseña reside en el repositorio.
* ✅ **Sin Credenciales Estáticas:** No se utilizan client secrets, certificados ni tokens con fecha de caducidad guardados en Kubernetes.
* ✅ **Rotación Automática:** Los cambios de versión o valor en Key Vault se reflejan automáticamente en los Kubernetes Secrets en cada ciclo de refresco.
