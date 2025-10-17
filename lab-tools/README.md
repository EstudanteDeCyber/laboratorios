# 🛠️ Lab-Tools — Ferramentas de Cyber (capa)

Repositório com um conjunto de **ferramentas de cibersegurança** (SaaS/self-hosted) empacotadas em containers ou VMs para uso em laboratórios — scanners, C2/engajamento, vaults, analisadores, SIEM, VPNs, entre outros. Este README é uma **visão geral inicial** (capa) para quem chegar no repositório; a documentação específica por ferramenta está nos READMEs locais e nos scripts de provisionamento.

---

## 🗂️ Estrutura principal (resumo)

```
lab-tools/
├── docker-tools-<app>/            # Ex.: docker-tools-splunk, docker-tools-openvas, ...
│     ├── docker-compose.yml or setup.sh
│     └── README.md                # instruções específicas por ferramenta
├── vagrant-docker-tools/
│     └── Vagrantfile              # <--- Arquivo principal para subir a VM Docker-Tools e provisionar TODOS os containers
├── vagrant-kali/
│     └── Vagrantfile              # <--- Kali VM (desktop) para testes e uso das ferramentas
└── horusec/                       # Exemplo de ferramenta com script de setup local
```

Conteúdo de exemplos: DefectDojo, Gophish, HashiCorp Vault, Inbucket, Nessus Essentials, OpenVAS, OpenVPN, Splunk, WAF2PY, Horusec, entre outros.

---

## 🎯 Objetivo rápido

- Prover um conjunto de **ferramentas operacionais** para testes, análise e pipelines de segurança (scanning, triagem, phishing, vaulting, logging, etc.).
    
- Orquestrar a execução via **Vagrant** — uma VM (`Docker-Tools`) que sobe e gerencia os containers das ferramentas.
    
- Disponibilizar uma VM **Kali** como estação de ataque/integração quando necessário.
    

---

## 🚀 Como iniciar (ponto de entrada)

### 1) Subir a stack completa de ferramentas (recomendado)

```powershell
cd lab-tools\vagrant-docker-tools
vagrant up
# ou (se houver script helper)
.\vagrant-up.ps1
```

> O `Vagrantfile` em `vagrant-docker-tools` é o **arquivo principal** responsável por criar a VM `Docker-Tools` (Debian) e executar o script de provisionamento (`provisionamento_docker_tools.sh`) que irá provisionar os containers das ferramentas.

### 2) Subir a VM Kali (opcional / desktop)

```powershell
cd lab-tools\vagrant-kali
vagrant up
```

> A VM `Kali` é útil para interagir com as ferramentas, executar pentests e usar como estação administrativa.

### 3) Subida modular de uma ferramenta específica (opcional)

Qualquer ferramenta/container pode ser iniciada modularmente entrando na pasta correspondente:

```bash
cd lab-tools\docker-tools-<app>
# se houver docker-compose.yml
docker-compose up -d

# ou, se houver setup.sh
./setup.sh
```

> Todos os deploys individuais usam scripts automatizados presentes em `.\scripts` (quando aplicável).

---

## 🔁 Scripts e automação

- O deploy orquestrado da stack usa o script referenciado pelo Vagrantfile (`/tmp/provisionamento_docker_tools.sh`).
    
- Scripts de deploy individuais e utilitários costumam ficar em `./scripts` (ver cada pasta ou o Vagrantfile para caminhos específicos).
    

---

## 🔌 Rede, portas e recursos

- O `Vagrantfile` da VM `Docker-Tools` define recursos (ex.: **6 GB RAM**, 2 CPUs no exemplo) — ajuste conforme disponibilidade do host.
    
- Verifique os `docker-compose.yml` e os READMEs das ferramentas para portas expostas e mapeamentos. Recomenda-se usar rede isolada / interna ao lab.
    

---

## 💾 Requisitos mínimos sugeridos

- **Vagrant**
    
- **VirtualBox** (ou outro provider suportado)
    
- **Docker** / **docker-compose** (caso execute containers localmente)
    
- Host com **6–12 GB** RAM livre para rodar confortavelmente a VM + containers (dependendo do conjunto de ferramentas).
    

---

## 🔐 Segurança e responsabilidade

- **Ambiente operacional**: muitas ferramentas possuem interfaces poderosas (scanners, SIEM, agentes). Use **rede isolada** e não exponha serviços à Internet pública.
    
- Uso **exclusivamente educacional** e em ambientes controlados. Não executar ações que impactem terceiros sem autorização explícita.
    

---

## ✅ Estado esperado após provisionamento

- `vagrant up` em `vagrant-docker-tools` provisiona a VM `Docker-Tools` e aciona os scripts que devem trazer as ferramentas em containers para um estado operacional.
    
- `vagrant up` em `vagrant-kali` provisiona a estação Kali pronta para uso.
    
- Em resumo: **após seguir os passos acima, o lab estará funcional para uso das ferramentas.**
    

---

## 🧭 Onde procurar mais detalhes

- README e `docker-compose.yml` em cada pasta `docker-tools-<app>` contêm instruções específicas (credenciais, portas, variáveis).
    
- Consulte `vagrant-docker-tools/Vagrantfile` para saber exatamente qual script de provisionamento é usado e os parâmetros da VM.
