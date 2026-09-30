# platform-gitops — GitOps y Entrega Progresiva en Kubernetes

Repositorio central de configuración declarativa del clúster AKS para el laboratorio DevOps/SRE.

## 1. Estructura del Repositorio

```text
platform-gitops/
├── apps/
│   └── online-boutique/
│       ├── base/
│       │   ├── deployment-frontend.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           │   └── kustomization.yaml    <-- Actualizado automáticamente por el CI de P2
│           └── prod/
│               └── kustomization.yaml
├── .gitignore
└── README.md
```

## 2. Flujo de Promoción GitOps (P2 → P3)

1. **Compilación y Firma (CI en `online-boutique-ci`):** Al realizar un merge o commit en `main`, el pipeline de CI construye la imagen, la escanea con Trivy, genera el SBOM con Syft, la publica en ACR y la firma con Cosign.
2. **Pull Request Automático:** El step final de promoción clona este repositorio, actualiza el tag del contenedor en `apps/online-boutique/overlays/dev/kustomization.yaml` mediante `kustomize edit set image` y abre un Pull Request hacia la rama `main`.
3. **Revisión y Merge:** El equipo de plataforma / SRE aprueba y fusiona el PR.
4. **Reconciliación Automática (CD con Argo CD en P3):** Argo CD detecta el cambio en Git y sincroniza el estado deseado en el clúster AKS.
