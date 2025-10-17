🧩 Laboratório Active Directory

Este repositório contém o **Laboratório Active Directory**, um ambiente virtualizado construído com **Vagrant** para estudos e simulações envolvendo **infraestrutura Windows**, **Active Directory**, **scripts de provisionamento** e, futuramente, **testes de vulnerabilidades controladas**.

---

## 📘 Visão Geral

O laboratório automatiza a criação de um ambiente composto por:

|Host|Função|Sistema Operacional|Observações|
|---|---|---|---|
|**DC01**|Controlador de Domínio (Active Directory)|Windows Server|Provisionado em 3 etapas|
|**SRV01**|Servidor de apoio|Windows Server|Scripts específicos de configuração|
|**CLI01**|Estação cliente|Windows 11|Conectada ao domínio após deploy|

O ambiente é definido pelo arquivo **`Vagrantfile`**, que configura as VMs, redes virtuais e parâmetros básicos de provisionamento.

> 💡 **Nota:** Está prevista a inclusão futura de **scripts de vulnerabilidade e exploração controlada** para estudos de segurança e hardening neste mesmo lab.

---

## 🚀 Inicialização e Provisionamento

### 1️⃣ Subida inicial das VMs

```powershell
# Copiar o script para a pasta do lab-ad (ou adicionar ao PATH)
scripts\vagrant-up.ps1

# Executar
.\vagrant-up.ps1
# ou simplesmente
vagrant up
```

> ⚠️ Durante o provisionamento, **reinicie manualmente a VM Windows 11** caso ela trave ou não inicialize corretamente.

---

### 2️⃣ Ajuste das placas de rede pós-deploy

```powershell
# Copiar o script para a pasta do lab-ad (ou adicionar ao PATH)
scripts\post_deploy_script.ps1

# Executar
.\post_deploy_script.ps1
```

---

### 3️⃣ Provisionamento do DC01

Após o deploy, logar na VM **DC01** e executar em ordem:

```cmd
cd c:\tmp\
.\dc01_provision_1.ps1
.\dc01_provision_2.ps1
.\cria_user_ad.ps1
```

---

### 4️⃣ Provisionamento do SRV01

```cmd
cd c:\tmp\
.\srv01_provision.ps1
```

---

### 5️⃣ Provisionamento do CLI01

```cmd
cd c:\tmp\
.\cli01_provision.ps1
```

---

## 🧱 Estrutura do Repositório

```
/
├── Vagrantfile               # Define a infraestrutura virtual
├── scripts/
│   ├── vagrant-up.ps1        # Subida e provisão inicial
│   ├── post_deploy_script.ps1 # Ajustes de rede pós-deploy
│   ├── dc01_provision_*.ps1  # Scripts do controlador de domínio
│   ├── srv01_provision.ps1   # Script do servidor auxiliar
│   └── cli01_provision.ps1   # Script do cliente Windows
└── README.md                 # Este documento
```

---

## 📌 Requisitos

- **Vagrant**    
- **VirtualBox** (ou provedor compatível)    
- **Windows 11 / Windows Server ISOs**    
- **PowerShell 5+**    

---

## 🧠 Próximos Passos

- Adição de scripts para estudo de **vulnerabilidades conhecidas** 
