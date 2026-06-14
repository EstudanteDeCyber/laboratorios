

---

# 🧱 InfraOpen Lab

O **InfraOpen Lab** é um ambiente de laboratório automatizado para estudos de **infraestrutura Linux**, **rede**, **serviços básicos** (DNS, NTP, Syslog, Samba, LAMP, etc.) e **segurança**, totalmente provisionado via **Vagrant**.

---

## ⚙️ Visão Geral

O ambiente define uma **rede interna virtual (`infraopen_network`)** composta por múltiplas VMs, cada uma com funções específicas (firewall, DNS, NTP, web, etc.).

Cada VM possui seu próprio **script de deploy** localizado em `/scripts`, responsável por instalar e configurar os serviços necessários — resultando em um **lab totalmente funcional** ao final do processo.

---

## 🧩 Estrutura do Projeto

```
/
├── Vagrantfile               # Define as VMs, rede e recursos principais
├── vagrant_helpers.rb        # Funções auxiliares de configuração
├── scripts/                  # Scripts de deploy e provisionamento por VM
│   ├── firewall_provision.sh
│   ├── dns1_provision.sh
│   ├── dns2_provision.sh
│   ├── samba_provision.sh
│   ├── ntp_provision.sh
│   ├── syslog_provision.sh
│   ├── lamp_provision.sh
│   ├── sftp_provision.sh
│   ├── webmin_provision.sh
│   └── ...
├── keys/                     # Chaves públicas usadas para autenticação SSH
│   └── [copiar sua chave pub aqui]
└── outros/                   # Materiais auxiliares e arquivos de referência
```

---

## 🚀 Inicialização

### 1️⃣ Subida das VMs

```powershell
# Copiar o script para a pasta raiz do lab (ou adicionar ao PATH)
.\vagrant-up.ps1

# Ou simplesmente
vagrant up
```

Durante a inicialização, o ambiente:

- Cria a rede interna `infraopen_network`
    
- Configura as VMs com os recursos definidos (CPU, memória, hostname, MAC/IP fixos)
    
- Executa scripts de atualização, ajustes regionais e deploy dos serviços correspondentes a cada host
    

---

## 🔐 Acesso e Chaves

- As chaves SSH estão sincronizadas entre `keys/` e `/tmp/tmp_key` nas VMs.
    
- A VM **firewall** é responsável por gerar e distribuir a chave pública para os demais hosts durante o provisionamento.
    

---

## 🧠 Pós-Deploy

Após a execução completa do `vagrant up`, todas as VMs estarão:

- Com acesso interno funcional entre si
    
- Com serviços instalados conforme seu papel
    
- Prontas para uso em testes de rede, configuração e segurança
    

---

## 📦 Requisitos

- **Vagrant**
    
- **VirtualBox** (ou outro provedor compatível)
    
- **PowerShell / Bash**
    
- Chave SSH pública configurada no host (ex.: `C:/Users/Hugo/.ssh/id_rsa.pub`)
    

---

## 📌 Próximos Passos

- Integração com ferramentas de **monitoramento e automação (Ansible)**
    
- Inclusão de **módulos de vulnerabilidade e hardening**
    
- Documentação detalhada de cada VM e respectivo serviço
    

---

> 🔍 **Nota:** Este README serve apenas como visão geral inicial.  
> A documentação detalhada de cada VM, scripts e fluxos de rede será adicionada futuramente em seções específicas.
