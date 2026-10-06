# ADR 001: Estrategia de Manifiestos para GitOps — Kustomize vs. Helm

* **Estado:** Aceptado
* **Fecha:** 2026-10-05
* **Decisores:** Equipo DevOps & SRE
* **Contexto:** Tarea P3-01 (Work Item #32) — Proyecto 3 (`platform-gitops`)

---

## 1. Contexto y Problema

Para el despliegue declarativo de la aplicación **Google Online Boutique** y de los componentes de plataforma en el clúster de Kubernetes mediante **Argo CD**, se requiere definir cómo se gestionan y versionan los manifiestos base y las variaciones entre entornos (`dev` y `prod`):

Existen dos alternativas estándar en el ecosistema Kubernetes:
1. **Helm Charts:** Utilizar el chart de Helm oficial de Online Boutique o renderizarlo mediante `helm template` / Argo CD Helm plugin.
2. **Kustomize Nativo:** Utilizar manifiestos YAML puros organizados en una capa base (`base/`) y capas de sobreescritura/parches por entorno (`overlays/dev/`, `overlays/prod/`).

---

## 2. Decisión

Hemos decidido adoptar **Kustomize nativo** como el estándar de gestión de manifiestos tanto para la aplicación (`apps/online-boutique`) como para las definiciones a nivel de clúster (`clusters/dev`).

---

## 3. Justificación y Análisis Comparativo

| Criterio de Evaluación | Helm Charts / Helm en Argo CD | Kustomize Nativo (Opción Elegida) |
| :--- | :--- | :--- |
| **Transparencia y Depuración** | Manifiestos con lógica de plantillas Go (`{{ if }}`, `{{ range }}`). Dificulta el análisis estático offline sin pasar por el motor de Helm. | Manifiestos YAML válidos y legibles en todo momento. Inspección directa con `kubectl diff`, `kustomize build` y `kubeconform`. |
| **Integración con CI y Promoción** | Requiere modificar `values.yaml` o usar regex/yq para alterar versiones, con riesgo de errores de indentación. | Permite mutaciones nativas, deterministas y atómicas con `kustomize edit set image`, utilizado en nuestro pipeline de CI (**P2-06**). |
| **Separación de Ambientes** | Depende de múltiples archivos `values-dev.yaml`, `values-prod.yaml` que a menudo duplican configuraciones globales. | Modelo canónico `base` + `overlays` donde los cambios entre entornos se expresan únicamente como parches diferenciales (Strategic Merge Patches). |
| **Dependencias de Infraestructura** | Requiere repositorios de charts (OCI o Helm repo HTTP) o empaquetado de artefactos `.tgz`. | Cero dependencias externas: todo reside directamente en Git (*Single Source of Truth*). |
| **Soporte Nativo en Herramientas** | Requiere binario de Helm o plugins adicionales. | Integrado nativamente en `kubectl` (`kubectl apply -k`) y soportado *out-of-the-box* por Argo CD. |

---

## 4. Consecuencias y Reglas Operativas

1. **Estructura Canónica:**
   * `apps/online-boutique/base/`: Contiene la definición declarativa completa de los 11 microservicios y `redis-cart`.
   * `apps/online-boutique/overlays/dev/`: Aplica namespace `online-boutique`, parches de recursos y réplicas reducidas (1 réplica por servicio), y recibe actualizaciones automáticas de CI (`sha-<corto>`).
   * `apps/online-boutique/overlays/prod/`: Aplica réplicas para alta disponibilidad (HA) y recursos ampliados con tags estables (`v1.0.0`).
2. **Validación en Shift-Left:**
   * Todo Pull Request sobre este repositorio es validado en GitHub Actions ejecutando `kustomize build` y `kubeconform` en modo estricto.
3. **Evolución Futura (P3-02 en adelante):**
   * Argo CD utilizará el generador nativo de Kustomize para sincronizar las aplicaciones hacia los clústeres de Kubernetes sin pasos intermedios de renderizado de plantillas.
