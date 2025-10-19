
---

# ⚠️ Docker Vuln & Metasploitable — Vulnerable Apps Lab

Ambiente de laboratório com múltiplas **aplicações vulneráveis em Docker** e VMs **Metasploitable** para estudos de segurança ofensiva, análise de vulnerabilidades e testes de ferramentas. Este README é uma visão geral inicial — documentação detalhada por aplicação/serviço está nos READMEs e scripts de cada pasta.

---

## 🗂️ Estrutura principal (resumo)

```
lab-vuln/
├── docker-vuln-<app>/             # Ex.: docker-vuln-juice-shop, docker-vuln-DVWA, ...
│     ├── docker-compose.yml or setup.sh
│     └── README.md                # instruções específicas por app
├── vagrant-docker-vuln/
│     └── Vagrantfile              # <--- Arquivo principal para subir a VM Docker-Vuln e TODOS os containers
└── vagrant-metasploitable/
      └── Vagrantfile              # <--- Arquivo principal para o ambiente Metasploitable
```

As aplicações incluídas (exemplos): Juice Shop, DVWA, bWAPP, NodeGoat, Badstore, WebGoat, Pixi, SecurityShepherd, WrongSecrets, Zap Webswing, Hackazon, entre outras.

---

## 🔧 Objetivo rápido

- Oferecer um conjunto de aplicações vulneráveis containerizadas para prática de pentest e treino em segurança web.
    
- Fornecer VMs Metasploitable (Linux / Windows) para exploração de vulnerabilidades de SO e serviços.
    
- Cada aplicação tem seu próprio deploy automatizado em `./scripts` (deploy por script/docket-compose).
    

---

## 🚀 Como iniciar (ponto de entrada)

### 1) Levantar toda a stack de containers (recomendado)

```powershell
cd lab-vuln\vagrant-docker-vuln
vagrant up
# ou, se existir script local:
.\vagrant-up.ps1
```

> **Nota:** esse Vagrantfile é o _arquivo principal_ responsável por provisionar a VM `Docker-Vuln` e orquestrar o deploy de TODOS os containers via o script de provisionamento referenciado nele.

### 2) Levantar o ambiente Metasploitable

```powershell
cd lab-vuln\vagrant-metasploitable
vagrant up
```

> **Nota:** este Vagrantfile provisiona Metasploitable2/3 (Linux e Windows) conforme definido.

### 3) Subida modular de containers (opcional)

Qualquer container pode ser iniciado de forma modular entrando na pasta correspondente:

```bash
cd lab-vuln\docker-vuln-<app>
# se houver docker-compose.yml
docker-compose up -d

# ou, se houver setup.sh
./setup.sh
```

> Todos os deploys individuais também usam scripts automatizados em `.\scripts`.

---

## 🔁 Scripts e automação

- O deploy automatizado dos containers e ações comuns está em `.\scripts` (copiar/ler e executar quando necessário).
    
- O `Vagrantfile` em `vagrant-docker-vuln` baixa/executa `/tmp/provisionamento_docker_vuln.sh` que orquestra a criação dos containers.
    

---

## 🔌 Rede, IPs e recursos

- Alguns Vagrantfiles definem IPs estáticos (ex.: `10.10.10.102`, `10.10.10.20`, `10.10.10.30`, etc.) e redes internas; verifique os Vagrantfiles antes do deploy.
    
- Recomendado ter **4–8 GB** de RAM disponíveis no host para rodar a VM + containers confortavelmente (o Vagrantfile já define memória por VM).
    

---

## 🔐 Segurança e responsabilidade

- **Ambiente intencionalmente inseguro.** Use sempre **rede isolada** (rede interna / NAT) e não exponha em redes públicas.
    
- Uso **exclusivamente educacional**. Não realize testes fora de um ambiente controlado ou sem autorização.
    

---

## ✅ Estado esperado após provisionamento

- Ao executar `vagrant up` em `lab-vuln\vagrant-docker-vuln`, a VM `Docker-Vuln` será provisionada e deverá subir os containers das aplicações vulneráveis automaticamente.
    
- Ao executar `vagrant up` em `lab-vuln\vagrant-metasploitable`, as VMs Metasploitable estarão configuradas e prontas para exploração.
    
- Em suma: **após seguir os passos acima, o lab estará funcional** como ambiente de estudos.
    

---

## 🧭 Onde procurar mais detalhes

- Cada subdiretório `docker-vuln-<app>` tem seu `README.md` com instruções, portas e credenciais (quando aplicável).
    
- Verifique `lab-vuln\vagrant-docker-vuln\Vagrantfile` e `lab-vuln\vagrant-metasploitable\Vagrantfile` para comportamento de provisionamento e scripts referenciados.
