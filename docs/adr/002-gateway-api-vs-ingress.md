# ADR 002: Adopción de Kubernetes Gateway API vs. Ingress Controller Clásico

* **Estado:** Aceptado
* **Fecha:** 2026-10-06
* **Decisores:** Equipo DevOps & SRE
* **Contexto:** Tarea P3-04 (Work Item #35) — Proyecto 3 (`platform-gitops`)

---

## 1. Contexto y Problema

Para exponer de forma segura y escalable la aplicación **Online Boutique** al exterior mediante HTTP/HTTPS con terminación TLS, el clúster requiere un mecanismo de enrutamiento de capa 7 (L7).

Históricamente, el estándar en Kubernetes ha sido el recurso `Ingress` (frecuentemente implementado con `ingress-nginx`). Sin embargo, el recurso `Ingress` adolece de limitaciones arquitectónicas conocidas:
* API monolítica que no distingue roles (infraestructura, operaciones y desarrolladores de aplicaciones compiten por el mismo recurso).
* Fuerte dependencia de anotaciones propietarias vendor-specific (`nginx.ingress.kubernetes.io/*`), dificultando la portabilidad y validación estática de esquemas.
* Soporte limitado o inexistente de forma nativa para división porcentual de tráfico (*traffic splitting*), redirecciones avanzadas o múltiples listeners TLS sin hackear anotaciones.

---

## 2. Decisión

Adoptar la especificación oficial de **Kubernetes Gateway API** utilizando **Envoy Gateway** como implementación de plano de datos/control, junto con **cert-manager** para la emisión automatizada de certificados TLS mediante ACME/Let's Encrypt.

---

## 3. Justificación y Análisis Comparativo

| Criterio de Evaluación | Ingress Clásico (`Ingress` / NGINX) | Gateway API (`Envoy Gateway`) [Elegido] |
| :--- | :--- | :--- |
| **Separación de Responsabilidades** | Monolítico: admin de clúster y devs configuran el mismo `Ingress`. | Orientado a Roles: Admin define `GatewayClass`, Plataforma define `Gateway` y Devs definen `HTTPRoute`. |
| **Portabilidad y Validación** | Anotaciones libres no tipadas (no validables con `kubeconform`). | CRDs fuertemente tipados (`gateway.networking.k8s.io/v1`) con esquemas OpenAPI estrictos. |
| **Traffic Splitting Nativo** | Requiere hacks de anotaciones canarias complejas. | Nativo en `HTTPRoute` (`backendRefs` con pesos `weight`). |
| **Integración TLS / cert-manager** | Anotación `cert-manager.io/cluster-issuer` en Ingress. | Soporte nativo de `Certificate` y secret TLS referenciado directamente en `Gateway.spec.listeners`. |
| **Motor de Rendimiento** | NGINX tradicional con recargas de configuración (`reload`). | Envoy Proxy con xDS dinámico sin pérdida de conexiones ni recargas de procesos. |

---

## 4. Consecuencias

* Las rutas de entrada a microservicios se expresan de forma limpia e independiente mediante `HTTPRoute` en el namespace de la aplicación (`online-boutique`).
* La infraestructura de entrada (`Gateway` y certificados TLS) se desacopla en la capa transversal de plataforma (`platform/gateway`).
* El clúster se alinea con el estándar oficial de SIG Network de Kubernetes para la próxima década.
