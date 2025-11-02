# 🚀 VPS Deterministic Rescue Kit con Ansible

Questo repository è un **kit di strumenti di ripristino d'emergenza**, programmabile e sicuro, progettato per sbloccare un VPS Linux che non si avvia a causa dell’esaurimento di risorse (RAM/CPU) causato da servizi automatici (Docker, Podman, Cron, systemd timers, ecc.).

La sicurezza del sistema si basa su un **Processo Obbligatorio a Tre Fasi**, che garantisce l’analisi dei dati prima di qualsiasi intervento correttivo sul disco bloccato.

---

## 1. 📂 Struttura del Repository

Il repository è strutturato per separare l’infrastruttura di Ansible, gli script di bootstrap e la documentazione.

```

vps-deterministic-rescue/
├── README.md                                # Documentazione (questo file)
├── ansible/                                 # Contiene i playbook e l’inventario
│   ├── diagnose_playbook.yml                # FASE 1: Acquisisce i log (NON SCRIVE sul disco VPS)
│   ├── fix_playbook.yml                     # FASE 3: Esegue le correzioni selettive (SCRIVE sul disco VPS)
│   ├── hosts_remote.ini                     # Inventario per il Workflow Remoto (Control Node)
│   ├── hosts_local.ini                      # Inventario per il Workflow Locale (Standalone)
│   └── group_vars/
│       └── all.yml                          # Variabili di configurazione (partizione, servizio da disabilitare)
└── scripts/
└── bootstrap.sh                         # Script per abilitare SSH sulla Live ISO (per Workflow Remoto)

```

---

## 2. 🚦 Workflow Operativo Dettagliato (Tre Fasi)

Il processo di ripristino deve seguire scrupolosamente questa sequenza logica per garantire che l’azione correttiva sia **mirata ed efficace**.

---

### 2.1. Preparazione Iniziale (Comune a entrambi i Workflow)

1. **Boot da Live ISO:**  
   Accedi al pannello di controllo del tuo provider VPS, monta una Live ISO (es. *Debian Rescue*) e avvia il VPS.

2. **Accesso Console:**  
   Accedi alla console VNC/Web del VPS.

3. **Conferma IP:**  
   Esegui `ip a` per confermare l’indirizzo IP assegnato alla Live ISO dal tuo provider (necessario per il Workflow Remoto).

4. **Configurazione Variabili:**  
   Verifica e, se necessario, aggiorna `target_partition` in `ansible/group_vars/all.yml` (es. `/dev/vda1` o `/dev/sda1`).

---

### 2.2. Fase 1: Diagnostica Non Distruttiva (`diagnose_playbook.yml`) 🧐

**Obiettivo:**  
Montare la partizione VPS in sola lettura, copiare i log recenti (`syslog`, `journalctl`, ecc.) in una directory temporanea sulla Live ISO e smontare.

**Comando di Esecuzione (Esempio Remoto):**
```bash
ansible-playbook -i ansible/hosts_remote.ini ansible/diagnose_playbook.yml
````

**Output Cruciale:**
La console indicherà il percorso esatto (es. `/tmp/logs_<timestamp>`) dove i log sono stati salvati.
Scarica questi log sulla tua macchina locale per l’analisi.

---

### 2.3. Fase 2: Analisi Umana e Decisione (Critica!) 🧠

**Obiettivo:**
Utilizzare i log acquisiti per identificare in modo deterministico il processo o servizio che ha causato l’esaurimento delle risorse.
**NON procedere oltre senza aver completato questa fase.**

| Causa Probabile     | Messaggio Chiave da Cercare                       | Azione Correggibile (Tag) |
| ------------------- | ------------------------------------------------- | ------------------------- |
| Esaurimento RAM     | `Out of memory / Killed process (ProcessName)`    | `--tags disable_service`  |
| Spazio/Inode Finiti | `No space left on device / Inode is already full` | `--tags cleanup`          |
| Servizio Bloccante  | `Failed to start [UnitName].service`              | `--tags disable_service`  |
| Corruzione FS       | `Errori di I/O`, `corrupted file`                 | `--tags fsck`             |

**Aggiornamento Variabili:**
Se l’analisi identifica un servizio da disabilitare (es. `podman.service`), aggiorna `service_to_disable` in `ansible/group_vars/all.yml` **prima della Fase 3**.

---

### 2.4. Fase 3: Risoluzione Granulare Selettiva (`fix_playbook.yml`) 🛠️

**Obiettivo:**
Eseguire **solo** i task correttivi necessari, utilizzando i tag Ansible.

**Esempio – Disabilitazione Servizio e Aggiornamento Bootloader:**

```bash
ansible-playbook -i ansible/hosts_remote.ini ansible/fix_playbook.yml --tags disable_service,grub
```

**Esempio – Solo Pulizia e Controllo Filesystem:**

```bash
ansible-playbook -i ansible/hosts_remote.ini ansible/fix_playbook.yml --tags cleanup,fsck
```

**Passo Finale:**
Al termine, scollega l’ISO dal pannello del provider e **riavvia il VPS**.

---

## 3. 🌐 Scelta del Workflow Dettagliata

Entrambi i workflow eseguono gli stessi playbook, ma differiscono nel modo in cui Ansible si connette al VPS Live.

---

### 3.1. Workflow Remoto (Control Node)

Questa è la modalità standard Ansible.
Devi eseguire `scripts/bootstrap.sh` nella console VNC/Web per abilitare l’accesso remoto.

**Passaggi:**

1. Esegui lo script `bootstrap.sh` sulla Live ISO.
2. Lo script stamperà l’IP, l’utente (`tempuser`) e la password temporanea.
3. Modifica `ansible/hosts_remote.ini` con l’IP e le credenziali.
4. Esegui i playbook dalla tua macchina locale (Control Node).

---

### 3.2. Workflow Locale (Standalone)

Ideale se hai problemi di connettività di rete.

**Passaggi:**

1. Installa Ansible direttamente sulla Live ISO (necessita connettività base per `apt`):

   ```bash
   apt update && apt install ansible -y
   ```
2. Utilizza l’inventario `ansible/hosts_local.ini` (che punta a `localhost`).
3. Esegui i playbook direttamente dalla console VNC/Web del VPS.

---

## 4. 🗃️ Variabili Critiche (`ansible/group_vars/all.yml`)

Questo file configura i parametri per l’intervento e deve essere aggiornato in base al tuo sistema.

```yaml
# FILE: ansible/group_vars/all.yml

# La partizione root del VPS bloccato. **VERIFICA** con `fdisk -l` sulla Live ISO.
target_partition: /dev/sda1

# Punto di mount temporaneo utilizzato dal playbook.
mount_point: /mnt/vps

# AGGIORNA DOPO LA FASE 2:
# Sostituisci con il nome esatto del servizio systemd o container da disabilitare.
# Esempi: docker.service, podman.service, nome_servizio_custom.service
service_to_disable: docker.service
```

---

✅ **Nota Finale:**
Questo kit è pensato per interventi deterministici e sicuri.
Non automatizza mai la correzione senza prima acquisire e analizzare i log.
Seguendo le tre fasi obbligatorie, puoi ripristinare un VPS bloccato senza rischiare ulteriori danni ai dati.
