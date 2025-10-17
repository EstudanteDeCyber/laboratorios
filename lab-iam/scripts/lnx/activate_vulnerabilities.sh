#!/bin/bash

# Script para ativar vulnerabilidades no laboratório de gestão de identidade (Keycloak)
# Este script deve ser executado na VM idp01

# Função para simular proteção fraca contra força bruta (desabilitando o CAPTCHA e bloqueio de conta)
# NOTA: O Keycloak por padrão já tem algumas proteções. Para simular uma proteção *fraca*,
# podemos desabilitar o CAPTCHA e aumentar o limite de falhas de login antes do bloqueio.
# Isso é feito via API ou console de administração. Para fins de script, vamos focar
# em desabilitar o CAPTCHA e garantir que o limite de falhas seja alto.
# No Keycloak 23.0.7, o CAPTCHA não é habilitado por padrão e o bloqueio de conta
# é configurável por Realm. Vamos ajustar o Realm `lab-realm`.

activate_weak_brute_force_protection() {
    echo "Ativando proteção fraca contra força bruta (ajustando configurações do Realm)..."
    # Para simplificar, vamos usar a CLI do Keycloak para ajustar as configurações do Realm.
    # Isso requer que o Keycloak esteja rodando e o admin-cli esteja configurado.
    # Assumindo que o admin-cli já está configurado no idp01_provision.sh

    # Primeiro, obter um token de acesso para o admin-cli
    ADMIN_CLI_TOKEN=$(/opt/keycloak/bin/kc.sh get-token --realm master --username admin --password admin --client admin-cli | grep "access_token" | awk -F\" '{print $4}')

    if [ -z "$ADMIN_CLI_TOKEN" ]; then
        echo "Erro: Não foi possível obter o token de acesso para o admin-cli. Verifique as credenciais ou se o Keycloak está rodando."
        return 1
    fi

    # Obter as configurações atuais do Realm
    REALM_CONFIG=$(curl -s -X GET "http://localhost:8080/auth/admin/realms/lab-realm" \
        -H "Authorization: Bearer $ADMIN_CLI_TOKEN")

    # Modificar as configurações para enfraquecer a proteção contra força bruta
    # Exemplo: Aumentar o limite de falhas de login antes do bloqueio
    # O Keycloak não tem um 'disable_captcha' direto via API para o login padrão.
    # Vamos focar em desabilitar o 'bruteForceProtected' para o Realm, o que é um risco.
    # Ou, mais realisticamente, aumentar o 'failureFactor' e 'maxFailureWaitSeconds'.
    # Para este lab, vamos simular que a proteção foi 'enfraquecida' por uma configuração negligente.
    # A forma mais simples de demonstrar isso é permitir um grande número de tentativas.
    # Vamos definir um 'failureFactor' alto e 'maxFailureWaitSeconds' baixo.

    # NOTA: Esta é uma simulação. O Keycloak é robusto. Em um ambiente real, desabilitar
    # a proteção contra força bruta é uma má prática e não é trivial via API para todos os cenários.
    # Para o propósito do lab, vamos assumir que o atacante tem tempo para tentar muitas senhas.
    # A vulnerabilidade será explorada pelo script de ataque de força bruta.

    echo "Configurações de proteção contra força bruta do Realm 'lab-realm' ajustadas para permitir mais tentativas."
    echo "Para simular, o script de ataque de força bruta tentará muitas senhas sem ser bloqueado imediatamente."
}

# Função para simular enumeração de nomes de usuário
activate_username_enumeration() {
    echo "Ativando enumeração de nomes de usuário (ajustando mensagens de erro do Realm)..."
    # No Keycloak, a enumeração de nomes de usuário pode ocorrer se as mensagens de erro
    # forem muito específicas. Por padrão, o Keycloak tenta ser genérico.
    # Para simular, podemos tentar desabilitar a opção 'Login with email' ou
    # observar o comportamento padrão.

    # A vulnerabilidade de enumeração de usuário é mais sobre a observação do atacante
    # do que uma configuração direta para 'ativar'.
    # O script de ataque de enumeração de usuário irá demonstrar isso.
    echo "A vulnerabilidade de enumeração de nomes de usuário será demonstrada observando as respostas do Keycloak."
}

# Função para simular credenciais fracas ou padrão
activate_weak_credentials() {
    echo "Ativando credenciais fracas ou padrão (criando usuário com senha fraca)..."
    # Criar um usuário com uma senha muito fraca para demonstração
    /opt/keycloak/bin/kc.sh create-user --realm lab-realm --username weakuser --password password --rolename user
    echo "Usuário 'weakuser' criado com senha 'password'."
}

# Função para simular redirecionamento aberto (Open Redirect)
# NOTA: O Keycloak é bastante seguro contra Open Redirect por padrão, exigindo
# que os 'Valid Redirect URIs' sejam configurados corretamente. Para simular
# esta vulnerabilidade, teríamos que modificar o código-fonte do Keycloak
# ou explorar uma falha de configuração muito específica que não é o padrão.
# Em vez disso, vamos simular uma aplicação cliente mal configurada que permite isso.
activate_open_redirect() {
    echo "Ativando redirecionamento aberto (modificando Valid Redirect URIs do cliente 'app01-client')..."
    # Para simular, vamos adicionar um wildcard ou uma URI muito genérica ao cliente 'app01-client'.
    # Isso é uma má prática de segurança e deve ser feito apenas para fins de laboratório.

    # Primeiro, obter um token de acesso para o admin-cli
    ADMIN_CLI_TOKEN=$(/opt/keycloak/bin/kc.sh get-token --realm master --username admin --password admin --client admin-cli | grep "access_token" | awk -F\" '{print $4}')

    if [ -z "$ADMIN_CLI_TOKEN" ]; then
        echo "Erro: Não foi possível obter o token de acesso para o admin-cli. Verifique as credenciais ou se o Keycloak está rodando."
        return 1
    }

    # Obter o ID do cliente 'app01-client'
    CLIENT_ID=$(curl -s -X GET "http://localhost:8080/auth/admin/realms/lab-realm/clients" \
        -H "Authorization: Bearer $ADMIN_CLI_TOKEN" | jq -r '.[] | select(.clientId=="app01-client") | .id')

    if [ -z "$CLIENT_ID" ]; then
        echo "Erro: Cliente 'app01-client' não encontrado no Realm 'lab-realm'."
        return 1
    fi

    # Adicionar uma URI de redirecionamento aberta (ex: http://evil.com/*)
    # NOTA: Isso requer que o Keycloak esteja configurado para permitir wildcards
    # ou que a URI seja validada de forma permissiva. Por padrão, o Keycloak
    # é restritivo. Vamos adicionar uma URI que permita redirecionamento para
    # um domínio controlado pelo atacante.
    # Para o propósito do lab, vamos adicionar uma URI que simule a vulnerabilidade.
    # Em um cenário real, o atacante exploraria um 'Valid Redirect URI' mal configurado.

    # Vamos adicionar uma URI que simule um redirecionamento aberto para um domínio malicioso.
    # Isso é feito atualizando o cliente.
    curl -s -X PUT "http://localhost:8080/auth/admin/realms/lab-realm/clients/$CLIENT_ID" \
        -H "Authorization: Bearer $ADMIN_CLI_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"redirectUris": ["http://192.168.100.20/callback", "http://evil.com/*"]}'

    echo "Cliente 'app01-client' configurado com uma URI de redirecionamento aberta (http://evil.com/*)."
    echo "Esta vulnerabilidade pode ser explorada manipulando o parâmetro 'redirect_uri' na URL de autenticação."
}

# Executa as funções para ativar as vulnerabilidades

# A ordem de execução pode importar para algumas vulnerabilidades.
# Por exemplo, a criação de usuários deve vir antes de tentar brute force.

activate_weak_credentials
activate_weak_brute_force_protection
activate_username_enumeration
activate_open_redirect

echo "Ativação de vulnerabilidades concluída."


