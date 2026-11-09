# TradeSim

Simulador de investimentos TradeSim, desenvolvido em Flutter.

## Arquitetura sugerida

```text
lib/
  main.dart
  models/
    asset_quote.dart
    trade_order.dart
    user.dart
    wallet.dart
    wallet_transaction.dart
  screens/                   # Login, carteira, cotações e ordens
  state/                     # Estado e regras de apresentação (Provider)
  services/
    brapi_service.dart        # Cotações da API pública Brapi
    local_json_store.dart     # Persistência mock local em JSON
  widgets/                   # Componentes reutilizáveis
```

O documento salvo em `shared_preferences` contém usuários, carteiras e a sessão
ativa. Ele atende ao protótipo local; não substitui um banco de dados seguro
para uso em produção. `LocalJsonStore.saveUser` cria ou atualiza o usuário e
persiste seus dados de carteira. As senhas são armazenadas como hash para esta
simulação, mas o login local não substitui um serviço de autenticação seguro.

O mercado carrega a lista paginada de ações diretamente do endpoint público
`/api/quote/list` da Brapi, incluindo nome, último fechamento, variação e
volume; a busca também é feita na API. Não há lista de ativos ou preços de
fallback no app. Se a API falhar, o mercado fica indisponível e novas ordens
não podem ser criadas usando cotações inventadas.

Ao selecionar uma ação no mercado ou na visão geral, o app abre a página de
detalhes com um gráfico e o histórico de fechamentos e variações por pregão,
consultados no endpoint de histórico da Brapi. É possível escolher o período
de 1, 3 ou 6 meses e 1 ano.

Para chamadas de cotação detalhada que exigem autenticação, abra o arquivo
`.env` na raiz do projeto e informe:

```dotenv
BRAPI_TOKEN=seu_token_da_brapi
```

Salve o arquivo e reinicie o app. O `.env` está no `.gitignore`; não remova essa
proteção nem compartilhe seu token. A configuração via `--dart-define` continua
disponível como alternativa. Tokens incluídos em um app cliente podem ser
extraídos do pacote; para produção, use um backend para proteger a credencial.

Para executar e validar o projeto:

```sh
flutter pub get
flutter run -d windows
flutter test
```

Crie uma conta na tela inicial. O simulador permite acompanhar cotações, buscar
ativos, adicionar/remover saldo simulado, comprar/vender swing trade e abrir
ou encerrar posições day trade. O encerramento calcula o P&L realizado e
registra as ordens no histórico local.
