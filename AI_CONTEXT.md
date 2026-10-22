# Contexto técnico do Starter

## Objetivo e limites

Starter é um template reutilizável de interface para novos aplicativos React Native e Expo. O repositório contém somente infraestrutura visual, navegação e controles demonstrativos. Não adicionar identidade, dados, autenticação ou lógica comercial de outro aplicativo.

O app funciona sem login, conexão, Firebase ou serviço de dados. O conteúdo de tela é estático ou mantido em estado local temporário.

## Runtime e navegação

- Expo SDK 58, React Native 0.88 e React 19.3.
- Expo Router com import estável expo-router/native-tabs.
- Stack nativa e Stack.Toolbar compartilhada.
- SF Symbols no iOS e ícones Material em outras plataformas.
- React Native organiza layout; SwiftUI e @expo/ui mantêm as interações próprias dos controles nativos.

## Componentes reutilizáveis

- ProgressiveCollapsibleScreen fornece títulos grandes e compactos, transição animada e blur de cabeçalho.
- ProgressiveBlur combina expo-blur, expo-linear-gradient e MaskedView.
- NativeSheet seleciona BottomSheet SwiftUI em Development Build iOS e fallback de gestos fora dele.
- NativeButton seleciona Button SwiftUI em Development Build iOS e fallback visual nos demais runtimes.
- NativeCardContextMenu usa ContextMenu SwiftUI no iOS e conteúdo sem menu nos fallbacks.
- NativeHomeToolbarActions cria ações SwiftUI hospedadas em Stack.Toolbar e expõe identificadores semânticos usados pelo plugin de sincronização.
- PremiumCard, GlassSurface e GlassButton dão estilos compartilhados aos exemplos.
- ThemeProvider mantém a preferência de aparência no armazenamento local do dispositivo.

## Adaptações nativas

- plugins/withStarterToolbarSync.js adapta o patch de react-native-screens 4.30.0 que sincroniza propriedade hidesBottomBarWhenPushed e ownership de toolbars compartilhadas durante navegação e morph.
- scripts/patch-expo-ui-bottom-sheet.js adiciona ignoresSafeArea(.container, edges: .bottom) ao BottomSheetView.swift de @expo/ui 58.0.19.
- `scripts/patch-expo-module-scan-timeout.js` aplica, com versão e ponto de patch verificados, o timeout de 30 segundos ao scanner Apple de `expo-modules-autolinking` 58.0.14. O limite upstream de 5 segundos causou a falha observada no Release; o scan continua obrigatório e ainda falha se não concluir dentro do novo prazo.
- O workflow Swift Preflight verifica o plugin, o patch e compila um app iOS Simulator sem assinatura.
- NativeSim usa o workflow manual do espelho público, túnel Cloudflare e gate autenticado. Nenhum token ou credencial permanente é necessário para o stream HTTP.
- `$starter-nativesim` é a skill principal de execução: exige a origem privada limpa e publicada, espelha automaticamente por allowlist quando necessário, reutiliza ou aguarda Preflight aprovado para o SHA exato, e inicia uma sessão pública de 120 minutos com exportação do artifact habilitada.
- A sessão NativeSim usa a CLI instalada numa cópia temporária do espelho, com push redirecionado a um sink local no mesmo SHA. Antes de publicar, o launcher executa `tests/StarterSecurity.Tests.ps1`, que usa somente fixtures temporárias e `gh` simulado. Antes de `up`, inspeciona o scaffold e o comportamento de commit automático da CLI instalada, verifica os templates do workflow e do gate, valida `gate.cjs` contra seu conteúdo normalizado aprovado e simula o scaffold real no clone isolado. A prévia deve preservar os dois arquivos gerados, o Git status e o HEAD; hashes, SHA e sink são verificados outra vez após a saída da CLI. `--export` envia `export_app=true`; após validar run ID, branch, SHA e ambos os links, o launcher encerra a CLI antes do download local. A execução remota exporta e publica o artifact, instala e abre o app, e mantém o stream ativo. A URL autenticada com `k` só é entregue ao usuário e nunca persistida.
- `$starter-simulator-archive` baixa um artifact existente assim que build, export e upload forem concluídos com sucesso, inclusive durante uma sessão ativa. Confirma identidade do run, SHA, nome e integridade do `.app.tar.gz`; nunca inicia Preflight, sessão ou build.

## Configuração e versões

app.config.js define Starter, scheme starter e bundle ID próprio `com.luanrigatti.starter`. Não há Firebase, identidade de assinatura Apple ou EAS projectId fixo. Só a variável `STARTER_EAS_PROJECT_ID`, quando explicitamente definida no workflow separado, liga o projeto. `eas.json` contém dois perfis de Simulator.

O Expo Router está em versão SDK 58 compatível com o módulo estável de abas. Não substituir por unstable-native-tabs sem uma auditoria explícita da versão instalada e dos comportamentos nativos.

## Regras de implementação

- Consultar a documentação versionada Expo SDK 58 antes de alterar APIs Expo.
- Preservar controles SwiftUI, animações, detents, menus, Liquid Glass, morph e hit testing nativos.
- Manter fallbacks necessários sem fazer o fallback substituir o controle nativo em Development Build iOS.
- Evitar dependências de rede, persistência remota e credenciais.
- Atualizar docs e testes direcionados junto com mudanças relevantes.
- Nunca usar este projeto para editar o checkout de origem.
