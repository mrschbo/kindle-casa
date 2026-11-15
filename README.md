# Kindle Casa

Painel doméstico personalizado para Kindle com KOReader.

## Componentes

- **Plugin KOReader:** exibe o painel diretamente no Kindle.
- **Editor web:** permite editar as informações pelo navegador.
- **Repositório privado `kindle-casa-dados`:** armazena os dados da casa em JSON.

## Editor

O editor é publicado pelo GitHub Pages e permite atualizar areia e ração dos gatos, tarefas, contas, datas de referência dos ciclos e anotações gerais. Também pode sincronizar os próximos eventos do Google Agenda (calendários principal e Família), em modo somente leitura.

## Privacidade e sincronização

Os dados domésticos ficam no repositório privado `kindle-casa-dados`. O editor usa um token informado pelo usuário para gravar o arquivo. O plugin do Kindle consulta esse arquivo pela API do GitHub e mantém uma cópia em cache local.

1. Crie um Fine-grained personal access token com acesso somente ao repositório `kindle-casa-dados`.
2. Em Repository permissions → Contents, conceda pelo menos Read-only.
3. No Kindle, abra KOReader → Ferramentas → Painel da Casa → Conectar dados do GitHub e informe o token.
4. O token fica no `config.json` local do Kindle. Não o publique nem o coloque no repositório público.

As alterações são feitas no editor web. O plugin apenas lê os dados e tenta sincronizar a cada 15 minutos. Sem Wi-Fi, continua exibindo o último painel sincronizado.

### Google Agenda

1. No Google Cloud Console, crie um projeto e habilite a Google Calendar API.
2. Configure a tela de consentimento OAuth e adicione sua conta como usuário de teste, se o app estiver em modo de teste.
3. Crie um ID de cliente OAuth do tipo Aplicativo da Web e cadastre `https://mrschbo.github.io` em Origens JavaScript autorizadas.
4. Cole o ID de cliente no editor, conecte sua conta Google e confirme as agendas principal e Família.
5. Sincronize os eventos e depois salve o painel no repositório privado.

O editor usa o fluxo OAuth de token do Google com escopo `calendar.readonly`. O token de acesso fica somente na memória da página e não é gravado no GitHub. Quando expirar ou a página for recarregada, será necessário autorizar novamente. O JSON privado guarda apenas nome do evento, início/fim, indicação de evento de dia inteiro e nome da agenda, limitado aos próximos 30 dias e a 40 eventos. O Kindle não recebe credenciais Google e só lê esses dados já sincronizados.

## Estrutura

- `index.html`: editor web.
- `kindlecasa.koplugin/`: plugin KOReader.
- `config-exemplo.json`: exemplo da configuração local.

## Créditos e licença

O projeto reutiliza componentes técnicos derivados do InkDeck, distribuído sob licença MIT. O crédito e o aviso de copyright originais são mantidos conforme os termos da licença. A interface, o painel doméstico e a integração de dados foram adaptados para o Kindle Casa.
