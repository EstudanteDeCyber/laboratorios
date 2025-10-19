#!/bin/bash
echo
echo "##################################################################"
echo "##   Aplicações Disponíveis abaixo. Divirta-se sem moderação!!  ##"
echo "##   Tire um print e acesse-as pelo KALI                      ##"
echo "##################################################################"
echo

# Obter o IP da máquina automaticamente
ip=$(ip addr show | grep -E 'inet [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
if [[ -z "$ip" ]]; then
    echo "Erro: Não foi possível obter o IP da máquina."
    exit 1
fi
base_url="http://$ip"

# Usar AWK para processar a saída de forma robusta e universal
docker ps --format '{{.Names}}\t{{.Ports}}' | awk -v base_url="$base_url" '
{
    name = $1;
    # A partir do 2o campo até o final, a string de portas
    ports_string = $0;
    sub(/^[^[:space:]]+[[:space:]]+/, "", ports_string);

    if (ports_string == "") {
        print "999999", name, "(sem portas expostas)";
        next;
    }

    # Separar as portas por vírgula
    split(ports_string, ports_array, ",");

    for (i in ports_array) {
        port = ports_array[i];

        # Remover espaços em branco
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", port);

        # Padrão para portas mapeadas (ex: 0.0.0.0:8080->8080/tcp)
        if (port ~ /->/) {
            split(port, parts, ":");
            sub(/\/tcp$/, "", parts[2]);
            split(parts[2], ports, "->");

            host_port = ports[1];
            container_port = ports[2];

            if (host_port != "" && container_port != "") {
                print host_port, name, base_url ":" host_port " -> " container_port;
            }

        # Padrão para portas internas (ex: 8080/tcp)
        } else if (port ~ /^[[:digit:]]+\/tcp/) {
            sub(/\/tcp$/, "", port);
            internal_port = port;
            if (internal_port != "") {
                print "999998", name, "(porta interna: " internal_port ")";
            }
        }
    }
}
' | sort -n | uniq | while IFS= read -r line; do
    container_name=$(echo "$line" | awk '{print $2}')
    details=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^[[:space:]]*//')
    printf "%-35s %s\n" "$container_name" "$details"
done
