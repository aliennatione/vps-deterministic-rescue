#!/usr/bin/env bash
# Usa 'set -euo pipefail' per fermare lo script al primo errore.
# Temporaneamente lo disattiviamo per garantire la rieseguibilità di 'apt install'.
set -e

USERNAME="tempuser"
# Password temporanea utilizzata da Ansible.
PASSWORD="TempPassGenerataEZ89!" 

echo "========================================"
echo "== VPS RESCUE BOOTSTRAP: Accesso Remoto =="
echo "========================================"

# --- FASE 1: Installazione e Creazione Utente ---

# Aggiornamento e installazione dei pacchetti essenziali
# Usiamo '|| true' per ignorare gli errori di blocco apt (se già in esecuzione)
apt-get update || true
apt-get install -y openssh-server net-tools curl || true

# Creazione dell'utente temporaneo solo se non esiste
if ! id "${USERNAME}" &>/dev/null; then
    echo "--> Creazione utente ${USERNAME}..."
    useradd -m -s /bin/bash "${USERNAME}"
fi

# Imposta la password (funziona anche se l'utente esisteva)
echo "--> Impostazione della password."
echo "${USERNAME}:${PASSWORD}" | chpasswd

# --- FASE 2: Risoluzione Permessi (Fix Sudo) ---

# Soluzione al problema "tempuser is not in the sudoers file".
# Aggiunge l'utente al gruppo 'sudo' (o 'wheel' se non trova 'sudo').
if grep -qE '^sudo:' /etc/group; then
    GROUP_NAME="sudo"
elif grep -qE '^wheel:' /etc/group; then
    GROUP_NAME="wheel"
else
    # Fallback se non trova gruppi comuni
    echo "ATTENZIONE: Nessun gruppo 'sudo' o 'wheel' trovato. Il playbook potrebbe fallire."
    GROUP_NAME=""
fi

if [ -n "${GROUP_NAME}" ]; then
    echo "--> Aggiunta di ${USERNAME} al gruppo ${GROUP_NAME} per i permessi di sudo."
    usermod -aG "${GROUP_NAME}" "${USERNAME}" || true
fi

# --- FASE 3: Configurazione SSH e Avvio ---

echo "--> Configurazione e riavvio SSH."
# Abilita il login con password (necessario per Ansible)
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Abilita il login di root se necessario (non strettamente richiesto da Ansible ma utile in Live)
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config

systemctl restart ssh || service ssh restart || true

# --- FASE 4: Output Finale ---

IP_ADDR=$(hostname -I | awk '{print $1}')

echo "----------------------------------------"
echo "✅ BOOTSTRAP COMPLETO E RESILIENTE"
echo "   IP Live ISO      : ${IP_ADDR}"
echo "   Utente SSH       : ${USERNAME}"
echo "   Password SSH/SUDO: ${PASSWORD}"
echo "----------------------------------------"
echo "Ora, sulla tua macchina locale (Control Node), esegui il playbook:"
echo "ansible-playbook -i ansible/hosts_remote.ini ansible/diagnose_playbook.yml --ask-become-pass"
