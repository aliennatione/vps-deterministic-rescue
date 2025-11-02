#!/usr/bin/env bash
set -euo pipefail

echo "== Bootstrapping SSH access on Live ISO =="

# 1. Installazione
apt-get update
apt-get install -y openssh-server net-tools

# 2. Creazione Utente Temporaneo
USERNAME="tempuser"
# Cambia questa password dopo la generazione se usi il repository in produzione
PASSWORD="TempPassGenerataEZ89!" 
useradd -m -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${PASSWORD}" | chpasswd

# 3. Configurazione e Avvio SSH
# Abilita il login con password (necessario per Ansible remote)
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# 4. Output e Notifica
IP_ADDR=$(hostname -I | awk '{print $1}')

echo "----------------------------------------"
echo "✅ SSH ACCESS READY"
echo "   IP address    : ${IP_ADDR}"
echo "   Connect with user: ${USERNAME}"
echo "   Password      : ${PASSWORD}"
echo "----------------------------------------"
echo "⚠️ Rimuovere l'utente una volta completato il ripristino."