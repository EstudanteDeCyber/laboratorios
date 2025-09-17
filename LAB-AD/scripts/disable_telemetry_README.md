# Script para Desativar Telemetria no Windows 10 e 11

Este script PowerShell foi desenvolvido para ajudar a desativar, bloquear e remover várias formas de telemetria e coleta de dados no Windows 10 e Windows 11. Ele aborda configurações de privacidade, serviços, tarefas agendadas e entradas no arquivo hosts para minimizar a quantidade de dados enviados à Microsoft.

## Conteúdo do Script

O script `disable_telemetry.ps1` executa as seguintes ações:

1.  **Desativação de Dados de Diagnóstico Opcionais**: Modifica configurações de registro para impedir o envio de dados de diagnóstico opcionais e experiências personalizadas.
2.  **Desativação de Outros Dados de Diagnóstico**: Desabilita a coleta de dados de fala, tinta e digitação para personalização.
3.  **Parada do Rastreamento de Atividades**: Desativa o histórico de atividades e o upload de atividades do usuário.
4.  **Desativação de Rastreadores de Publicidade**: Desabilita o ID de publicidade e experiências personalizadas baseadas em dados de diagnóstico.
5.  **Desativação do Recurso 'Encontrar Meu Dispositivo'**: Impede que o Windows rastreie a localização do dispositivo.
6.  **Desativação de Telemetria via Política de Grupo**: Configura a política de grupo para desativar a telemetria (aplicável a edições Pro/Enterprise/Education).
7.  **Desativação de Serviços de Telemetria**: Para e desabilita os serviços `DiagTrack` e `dmwappushservice`.
8.  **Bloqueio de Domínios de Telemetria via Arquivo Hosts**: Adiciona uma lista de domínios de telemetria conhecidos ao arquivo `hosts` do sistema, redirecionando-os para `0.0.0.0` para bloquear a comunicação.
9.  **Remoção de Tarefas Agendadas de Telemetria**: Remove várias tarefas agendadas que são responsáveis pela coleta e envio de dados de telemetria.

## Como Usar

1.  **Baixe o Script**: Faça o download do arquivo `disable_telemetry.ps1`.
2.  **Execute como Administrador**: Clique com o botão direito do mouse no arquivo `disable_telemetry.ps1` e selecione "Executar com PowerShell". Confirme a execução se o Controle de Conta de Usuário (UAC) solicitar.
3.  **Reinicie o Computador**: Para que todas as alterações entrem em vigor, é **altamente recomendável** reiniciar o seu computador após a execução do script.

## Observações Importantes

*   **Compatibilidade**: Este script foi projetado para Windows 10 e Windows 11. No entanto, algumas configurações podem variar ligeiramente entre as versões e compilações do sistema operacional.
*   **Privilégios de Administrador**: O script requer privilégios de administrador para modificar as configurações do sistema, serviços e o arquivo hosts.
*   **Reversão**: Não há uma função de reversão automática neste script. Se você precisar reativar a telemetria, terá que reverter as configurações manualmente ou usar pontos de restauração do sistema.
*   **Impacto**: Desativar a telemetria pode afetar a funcionalidade de alguns recursos do Windows que dependem da coleta de dados para melhorias ou relatórios de erros. No entanto, para a maioria dos usuários, o impacto é mínimo e os benefícios de privacidade superam os inconvenientes.
*   **Atualizações do Windows**: As atualizações futuras do Windows podem reverter algumas dessas configurações. Recomenda-se executar o script novamente após grandes atualizações do sistema operacional.

## Isenção de Responsabilidade

Use este script por sua conta e risco. O autor não se responsabiliza por quaisquer problemas ou danos que possam surgir do uso deste script. Sempre faça backup de seus dados importantes antes de fazer alterações significativas no sistema.

---

**Autor**: Manus AI


