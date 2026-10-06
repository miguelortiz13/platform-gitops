# Bootstrap — Patrón App-of-Apps para Argo CD

Este directorio aloja la configuración inicial para arrancar el clúster de Kubernetes siguiendo el patrón **app-of-apps** de Argo CD:

* **`root-application.yaml`:** Manifiesto de la aplicación raíz de Argo CD que monitorea y despliega la definición declarativa del clúster (`clusters/dev`).
* Permite que con un único comando imperativo inicial (`kubectl apply -f bootstrap/root-application.yaml`), Argo CD asuma el control total y continúe reconciliando de manera puramente declarativa todas las aplicaciones y recursos de plataforma.
