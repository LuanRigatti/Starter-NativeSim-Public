# Estado atual — Starter

## Snapshot operacional

Starter é um template independente de interface iOS em React Native, Expo SDK 58 e TypeScript. O conteúdo de demonstração funciona localmente; não há login, rede de dados, banco remoto, persistência comercial ou regras de negócio.

- Fonte privada: `C:\Projetos\Starter`, `LuanRigatti/Starter`, branch `main`.
- Espelho público filtrado: `C:\Projetos\Starter-NativeSim-Public`, `LuanRigatti/Starter-NativeSim-Public`, branch `main`.
- O espelhamento é unidirecional, parte de uma allowlist e registra o commit privado em `.nativesim-source` e nos trailers do commit público.
- A configuração padrão não contém `extra.eas.projectId`. Somente `STARTER_EAS_PROJECT_ID`, definido explicitamente no workflow EAS separado, pode vincular um projeto próprio.

## Versões e APIs

Antes da extração, a origem foi verificada em Expo 58.0.12, React Native 0.88.0, React 19.3.0, Expo Router 58.0.21, `@expo/ui` 58.0.19 e `react-native-screens` 4.30.0.

Depois de uma instalação limpa pelo lockfile, o Starter resolveu Expo 58.0.17, React Native 0.88.0, React 19.3.0, Expo Router 58.0.25, `@expo/ui` 58.0.22, `expo-linking` 58.0.14 e `react-native-screens` 4.30.0. `npx expo install --check` confirmou compatibilidade com o SDK 58.

NativeTabs usa o módulo estável `expo-router/native-tabs` e `NativeTabs.Trigger.Icon/Label`. A documentação versionada do SDK 58 recomenda Router `~58.0.25`; `unstable-native-tabs` não foi usado. Stack, Stack.Toolbar e os patches de toolbar permanecem integrados.

## Infraestrutura preservada

- ThemeProvider, tokens independentes azul/índigo, preferência local e temas claro/escuro.
- ProgressiveCollapsibleScreen, títulos grandes/compactos, animação durante scroll e Progressive Blur.
- NativeTabs, Native Stack, Stack.Toolbar compartilhada, SF Symbols e feedback tátil.
- NativeButton, NativeSheet, NativeCardContextMenu, ações de toolbar, cards e fallback multiplataforma.
- SwiftUI por `@expo/ui`, Bottom Sheet com detents/indicador de arraste, Context Menu e Liquid Glass real onde suportado.
- Reanimated, Gesture Handler, navegação push/pop e gesto nativo de retorno.
- `plugins/withStarterToolbarSync.js`, direcionado a `react-native-screens` 4.30.0.
- `scripts/patch-expo-ui-bottom-sheet.js`, aplicado após instalar `@expo/ui`; corrige a área segura inferior do BottomSheet SwiftUI.
- `scripts/patch-expo-module-scan-timeout.js`, aplicado no `postinstall`, altera o timeout hard-coded do scanner Apple em `expo-modules-autolinking` 58.0.14 de 5 para 30 segundos. A alteração é limitada à versão travada, falha fechada se o pacote ou o trecho mudar, preserva a descoberta dos módulos e mantém erro quando o scan excede o prazo. O motivo de o scanner ter passado de 5 segundos no runner Release ainda não foi isolado; a correção aguarda nova validação nativa autorizada.

## Telas e configuração

O app tem quatro abas demonstrativas — Início, Coleções, Buscar e Ajustes — e a rota de detalhe. Os textos e cartões são fictícios. A busca filtra apenas uma lista local; não há ações para salvar anexos ou conteúdo.

Nome, slug e scheme são `Starter`, `starter` e `starter`. O bundle ID é `com.luanrigatti.starter`, há ícone provisório e o alvo mínimo iOS é 16.4. Não foram copiados Firebase, autenticação, credenciais Apple nem um EAS project ID anterior. `eas.json` contém somente perfis de Simulator.

## Workflows e skills

- `swift-preflight.yml`: workflow manual para dependências, Expo, TypeScript, ESLint, testes, prebuild no runner macOS, Pods, patches e compilação Simulator sem assinatura.
- `native-sim.yml`: workflow manual compatível com a CLI NativeSim instalada; protege o streaming com gate, compila e instala o app sem certificado, exporta `.app.tar.gz` para artifact GitHub com retenção configurada de sete dias e aceita duração de 1 a 350 minutos. A duração padrão do fluxo Starter é 120 minutos; o timeout do job permanece em 360 minutos.
- `eas-build.yml`: workflow separado, manual e Simulator-only; exige token e ID de um projeto EAS novo configurados no repositório antes de qualquer build.
- `$starter-nativesim` é a skill principal: valida o Starter privado, roda `tests/StarterSecurity.Tests.ps1` com fixtures temporárias e `gh` simulado antes da publicação, publica o espelho somente com gates aprovados, reutiliza ou executa Swift Preflight para o SHA exato, envia `export_app=true`, inicia NativeSim e devolve os dois links completos antes do download local. O launcher verifica o scaffold real da CLI no clone isolado, valida as versões do workflow e do gate, compara o gate com o conteúdo aprovado após a normalização controlada, e confirma hashes/SHA/sink antes e depois da CLI. `$mirror-starter` rejeita reparse points em toda a origem e destino, incluindo ancestrais, e copia arquivos e grava a proveniência por substituição atômica para não seguir hard links no destino. O workflow remoto exporta e publica o artifact, instala e abre o app e mantém o stream ativo. `$mirror-starter` permanece para uso independente; `$starter-simulator-archive` baixa o artifact existente quando build/export/upload passam, inclusive com a sessão ainda ativa, sem iniciar outra execução.
- Skills locais em `.agents/skills/`: `mirror-starter`, `starter-nativesim`, `starter-swift-preflight` e `starter-simulator-archive`.

Esta atualização de skill/scripts não iniciou sessão NativeSim, build EAS, Swift Preflight ou compilação/prebuild nativo local. Na preparação inicial, o GitHub registrou nove checks `push` falhos no Starter privado, distribuídos pelos três workflows e três SHAs antigos. A API retornou zero jobs e zero check runs em todos os nove; os logs não existem. Os YAML declaram somente `workflow_dispatch`. Nenhum registro apareceu no espelho público. Trate esses checks como histórico sem jobs; não os use como resultado de build.

## Validação local

- `npm ci`: passou; instalou 1302 pacotes e o `postinstall` aplicou o patch BottomSheet.
- `npx expo install --check`: passou.
- `npx expo-doctor`: 20/20 verificações passaram.
- TypeScript: passou.
- ESLint: passou; Node emitiu somente um aviso de custo de reinterpretação do arquivo `eslint.config.js` como ES module.
- Jest: 4 testes passaram.
- Verificação dos contratos nativos: passou.
- Workflows YAML, sintaxe PowerShell e frontmatter/nome das quatro skills: passaram em verificações estruturais locais.
- `tests/StarterSecurity.Tests.ps1`: simula reparse points, escrita de proveniência redirecionada, scaffold NativeSim, gates de Preflight/sessões/URL/export e validação do archive.
- Validador oficial `quick_validate.py` das skills ficou pendente porque PyYAML não está instalado; nenhuma dependência extra foi instalada para contornar isso.

## Segurança e limites de evidência

A varredura do conteúdo do Starter não encontrou credenciais, arquivos restritos ou referências ao repositório/aplicativo anterior. `.env`, arquivos Firebase e certificados não fazem parte da allowlist do espelho.

`npm audit` reportou 46 entradas de vulnerabilidade no grafo (28 HIGH, 18 MODERATE); `npm audit --omit=dev` reportou 19 caminhos HIGH. As causas raiz incluem `braces` até 3.0.3 e `node-forge` até 1.4.0 (HIGH), além de `sprintf-js` até 1.1.3 (MODERATE). O GitHub Advisory Database não lista versões corrigidas para esses intervalos. Não foi aplicado `npm audit fix --force` nem override que rebaixe o Expo SDK.

TypeScript, ESLint, testes e configuração estática não comprovam o comportamento visual ou nativo. A toolbar compartilhada, o morph Liquid Glass, gestos, controles SwiftUI, blur e Bottom Sheet ainda precisam de validação real em iOS Simulator ou iPhone por meio do fluxo manual correspondente.
