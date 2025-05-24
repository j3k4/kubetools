# Kubetools

Dieses Docker-Image bietet eine umfassende Sammlung von Tools für die Arbeit mit Kubernetes-Clustern. Es enthält gängige CLI-Tools, einen vorkonfigurierten Zsh-Shell mit Oh My Zsh und Powerlevel10k sowie verschiedene `kubectl`-Plugins, um deine Produktivität zu steigern.

## Enthaltene Tools

### CLI-Tools
* **kubectl**: Das Standard-Kommandozeilen-Tool für Kubernetes.
* **helm**: Der Paketmanager für Kubernetes.
* **cilium CLI**: Kommandozeilen-Tool für die Interaktion mit Cilium.
* **kubeseal**: Tool zum Versiegeln von Kubernetes Secrets.
* **argocd**: CLI für Argo CD, das GitOps-Kontinuierliche Bereitstellungstool für Kubernetes.
* **velero**: Tool zur Sicherung und Wiederherstellung von Kubernetes-Cluster-Ressourcen und persistenten Volumes.
* **kubectx & kubens**: Zum schnellen Wechseln zwischen Kubernetes-Clustern und Namespaces.
* **k9s**: Ein terminalbasiertes UI zur Interaktion mit Kubernetes-Clustern.
* **ansible-core & ansible-lint**: Für die Automatisierung und Linting von Ansible-Playbooks.
* **flux**: Das CLI für Flux CD, ein weiteres GitOps-Tool für Kubernetes.
* **jq & yq**: Kommandozeilen-JSON- und YAML-Prozessoren.
* **git**: Versionskontrollsystem.
* **curl & tar**: Nützliche Tools für Netzwerkoperationen und Archivverwaltung.
* **rsync**: Schnelle inkrementelle Dateiübertragung.
* **byobu**: Eine erweiterte und benutzerfreundliche Textfensterverwaltung (basierend auf Tmux oder Screen).

### Shell-Verbesserungen
* **Zsh**: Eine leistungsstarke Shell.
* **Oh My Zsh**: Ein Framework zur Verwaltung deiner Zsh-Konfiguration.
* **Powerlevel10k**: Ein schnelles und anpassbares Theme für Zsh.
* **Awesome Vimrc**: Eine vorkonfigurierte Vim-Umgebung für eine verbesserte Bearbeitungserfahrung.

### Kubectl Plugins (via Krew)
* `images`
* `ktop`
* `np-viewer`
* `outdated`
* `plogs`
* `rbac-tool`
* `sick-pods`
* `status`
* `stern`
* `view-allocations`
* `view-cert`
* `view-quotas`
* `view-secret`
* `view-utilization`
* `virt`

## Build-Anleitung

Das Image kann für `linux/amd64` und `linux/arm64` Architekturen gebaut werden.

```bash
podman build --platform linux/amd64,linux/arm64 --manifest kubetool .
```

Ersetze `podman` durch `docker`, falls du Docker verwendest. Das `--manifest` Flag erstellt ein Manifest-List-Image, das mehrere Architekturen unterstützt.

## Verwendung

Um das Image interaktiv zu starten und deine `.kube`-Konfiguration zu mounten:

```bash
podman run -it -v $HOME/.kube:$HOME/.kube:z --rm kubetools
```

* `-it`: Startet den Container im interaktiven Modus mit einem TTY.
* `-v $HOME/.kube:$HOME/.kube:z`: Bind-mountet dein lokales `.kube`-Verzeichnis in den Container. Das `:z` Label ist für Podman/SELinux-Systeme relevant und erlaubt dem Container, auf das gemountete Volume zuzugreifen. Entferne es, wenn du Docker auf Nicht-SELinux-Systemen verwendest.
* `--rm`: Entfernt den Container automatisch, wenn er beendet wird.
* `kubetools`: Der Name deines gebauten Images.

Nach dem Start des Containers befindest du dich in einer Zsh-Shell, vorkonfiguriert und bereit für die Arbeit mit deinen Kubernetes-Clustern.

---