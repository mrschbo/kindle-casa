# Estrutura do plugin

O Kindle Casa é um painel doméstico de tela única para KOReader.

## Organização

- `main.lua`: integração com o menu e ciclo de vida do KOReader.
- `kindlecasa/core.lua`: inicialização e layout do painel.
- `kindlecasa/view.lua`: desenho e eventos da tela.
- `kindlecasa/widgets/casa.lua`: painel doméstico (clima, gatos, tarefas, contas e ciclos).
- `kindlecasa/github.lua`: leitura do arquivo privado `painel.json` e conversão dos dados.
- `kindlecasa/net.lua`: requisições HTTPS.
- `kindlecasa/util.lua`, `layout.lua`, `ui.lua` e `json.lua`: funções de apoio.

## Dados e cache

O editor grava o arquivo `painel.json` no repositório privado `kindle-casa-dados`. O plugin faz apenas leitura pela API do GitHub e salva a última resposta válida em `kindle-casa/cache/painel.json` no armazenamento do Kindle.

O token é configurado no menu do plugin e fica somente no `config.json` local do aparelho. Nunca inclua esse token no repositório público.

## Prévia e validação

A tela é desenhada pelo próprio plugin. A validação final de compatibilidade depende de executar no KOReader do Kindle, porque o ambiente de prévia no computador não reproduz integralmente APIs e componentes do dispositivo.
