# Kindle Casa

Painel doméstico personalizado para Kindle com KOReader.

## Componentes

- **Plugin KOReader:** exibe o painel diretamente no Kindle.
- **Editor web:** permite editar as informações pelo navegador.
- **Repositório privado `kindle-casa-dados`:** armazena os dados da casa em JSON.

## Editor

O editor é publicado pelo GitHub Pages e permite atualizar:

- Areia e ração dos gatos.
- Tarefas domésticas.
- Contas da casa.
- Datas de referência dos ciclos.
- Anotações gerais.

## Privacidade

Os dados domésticos ficam no repositório privado `kindle-casa-dados`.

O token de acesso é informado pelo usuário no editor e não deve ser incluído neste repositório.

## Estrutura de dados

O arquivo `painel.json`, armazenado no repositório privado, contém as informações utilizadas pelo painel.

## Licença

Projeto derivado do InkDeck. Consulte a licença MIT e preserve os créditos do projeto original.


## Sincronização no Kindle

O plugin consulta o arquivo privado `painel.json` pela API do GitHub e mantém uma cópia em cache no Kindle. Se estiver sem Wi-Fi ou o GitHub estiver indisponível, continua exibindo o último painel sincronizado.

1. Crie um **Fine-grained personal access token** no GitHub.
2. Em **Repository access**, selecione somente `kindle-casa-dados`.
3. Em **Permissions → Repository permissions → Contents**, selecione **Read-only**.
4. No Kindle, abra **KOReader → Ferramentas → Painel da Casa → Conectar dados do GitHub** e informe o token.
5. O token fica no `config.json` local do Kindle. Não o publique nem o coloque no repositório público.

A sincronização é somente de leitura: alterações são feitas no editor web, que grava no repositório privado. O plugin busca atualizações a cada 15 minutos (ajustável em `config.json`).

O plugin usa a base técnica do [InkDeck](https://github.com/louiskl/inkdeck), sob licença MIT, mantendo os créditos e a licença originais.
