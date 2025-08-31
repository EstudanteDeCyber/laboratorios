#!/bin/bash
echo
echo "##################################################################"
echo "##   Aplicacoes Disponiveis abaixo. Divirta-se sem moderacao!!  ##"
echo "##   Tire um pint e acesse-as pelo KALI                         ##"
echo "##################################################################"
echo

# Obter o IP da máquina automaticamente
ip=$(ip addr show | grep -E 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
if [[ -z "$ip" ]]; then
    echo "Erro: Não foi possível obter o IP da máquina."
    exit 1
fi
base_url="https://$ip"

# Primeira passagem: exibir apenas portas mapeadas (https)
docker ps --format '{{.Names}} {{.Ports}}' | while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    ports=$(echo "$line" | cut -d' ' -f2-)
    if [[ -z "$ports" ]]; then
        continue
    fi
    declare -A shown=()
    IFS=',' read -ra port_array <<< "$ports"
    for port in "${port_array[@]}"; do
        port=$(echo "$port" | xargs)
        if [[ "$port" == *"->"* ]]; then
            host_mapping=$(echo "$port" | cut -d'>' -f1)
            container_mapping=$(echo "$port" | cut -d'>' -f2)
            host_port=$(echo "$host_mapping" | awk -F':' '{print $NF}')
            container_port=$(echo "$container_mapping" | awk -F'/' '{print $1}')
            key="$host_port->$container_port"
            if [[ -z "${shown[$key]}" ]]; then
                printf "%-35s %s\n" "$name" "$base_url:$host_port -> $container_port"
                shown[$key]=1
            fi
        fi
    done
    unset shown
done

# Segunda passagem: exibir portas internas ou sem portas expostas
docker ps --format '{{.Names}} {{.Ports}}' | while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    ports=$(echo "$line" | cut -d' ' -f2-)
    declare -A shown=()
    if [[ -z "$ports" ]]; then
        printf "%-35s %s\n" "$name" "(sem portas expostas)"
        continue
    fi
    IFS=',' read -ra port_array <<< "$ports"
    for port in "${port_array[@]}"; do
        port=$(echo "$port" | xargs)
        if [[ "$port" != *"->"* ]]; then
            internal_port=$(echo "$port" | awk -F'/' '{print $1}')
            if [[ -z "${shown[$internal_port]}" ]]; then
                printf "%-35s %s\n" "$name" "(porta interna: $internal_port)"
                shown[$internal_port]=1
            fi
        fi
    done
    unset shown
done
