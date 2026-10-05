#!/usr/bin/env bash
# =====================================================================
# Préparation du VPS (à lancer UNE fois, en root, par toi — pas par Claude).
# Ubuntu 24.04 conseillé. Usage : sudo bash preparer-vps.sh
# =====================================================================
set -euo pipefail

UTILISATEUR=claude

echo "== 1. Mises à jour et pare-feu"
apt-get update -y && apt-get upgrade -y
apt-get install -y curl git make jq ufw unzip ca-certificates build-essential
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "== 2. Connexion SSH par clé uniquement"
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload ssh || systemctl reload sshd

echo "== 3. Utilisateur dédié à la boucle (Claude ne travaille jamais en root)"
id "$UTILISATEUR" >/dev/null 2>&1 || adduser --disabled-password --gecos "" "$UTILISATEUR"
mkdir -p /home/$UTILISATEUR/.ssh
cp /root/.ssh/authorized_keys /home/$UTILISATEUR/.ssh/ 2>/dev/null || true
chown -R $UTILISATEUR:$UTILISATEUR /home/$UTILISATEUR/.ssh

echo "== 4. Docker (pour construire les images et lancer les tests)"
curl -fsSL https://get.docker.com | sh
usermod -aG docker "$UTILISATEUR"

echo "== 5. k3s (Kubernetes léger, avec Traefik)"
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 600
# Registre d'images local accessible par k3s
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/registries.yaml <<'YAML'
mirrors:
  "registry.local:5000":
    endpoint:
      - "http://registry.local:5000"
YAML
grep -q 'registry.local' /etc/hosts || echo "127.0.0.1 registry.local" >> /etc/hosts
systemctl restart k3s

echo "== 6. Namespaces et accès limité pour la boucle (dev + staging, jamais prod)"
K="k3s kubectl"
for ns in dev staging prod registry; do $K create namespace $ns --dry-run=client -o yaml | $K apply -f -; done
$K -n dev create serviceaccount boucle --dry-run=client -o yaml | $K apply -f -
for ns in dev staging; do
  $K -n $ns create rolebinding boucle-admin --clusterrole=admin --serviceaccount=dev:boucle \
    --dry-run=client -o yaml | $K apply -f -
done
# Jeton longue durée pour le compte de service
cat <<'YAML' | $K apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: boucle-token
  namespace: dev
  annotations:
    kubernetes.io/service-account.name: boucle
type: kubernetes.io/service-account-token
YAML
sleep 3
TOKEN=$($K -n dev get secret boucle-token -o jsonpath='{.data.token}' | base64 -d)
CA=$($K -n dev get secret boucle-token -o jsonpath='{.data.ca\.crt}')
mkdir -p /home/$UTILISATEUR/.kube
cat > /home/$UTILISATEUR/.kube/boucle.yaml <<YAML
apiVersion: v1
kind: Config
clusters:
- name: vps
  cluster:
    server: https://127.0.0.1:6443
    certificate-authority-data: $CA
users:
- name: boucle
  user:
    token: $TOKEN
contexts:
- name: boucle
  context: { cluster: vps, user: boucle, namespace: dev }
current-context: boucle
YAML
chown -R $UTILISATEUR:$UTILISATEUR /home/$UTILISATEUR/.kube
chmod 600 /home/$UTILISATEUR/.kube/boucle.yaml

echo "== 7. Registre d'images dans le cluster"
cat <<'YAML' | $K apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: { name: registry, namespace: registry }
spec:
  replicas: 1
  selector: { matchLabels: { app: registry } }
  template:
    metadata: { labels: { app: registry } }
    spec:
      containers:
      - name: registry
        image: registry:2
        ports: [{ containerPort: 5000, hostPort: 5000 }]
        volumeMounts: [{ name: data, mountPath: /var/lib/registry }]
      volumes:
      - name: data
        hostPath: { path: /var/lib/registry-data, type: DirectoryOrCreate }
YAML

echo "== 8. Outils de développement : Go, Node.js, pnpm, Claude Code"
GO_VERSION=$(curl -s 'https://go.dev/VERSION?m=text' | head -1)
curl -sL "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" | tar -C /usr/local -xz
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> /home/$UTILISATEUR/.profile
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
npm install -g pnpm @anthropic-ai/claude-code

echo
echo "Terminé. Étapes suivantes (en tant que $UTILISATEUR) :"
echo "  ssh $UTILISATEUR@<ip-du-vps>"
echo "  claude            # se connecter une première fois à ton compte Claude"
echo "  git clone <ton-depot> plateforme && cd plateforme && cp env.example .env"
echo "  ./boucle.sh"
