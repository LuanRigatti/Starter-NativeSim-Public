# Instruções para agentes — Starter

## Escopo

Este é um template de UI para novos aplicativos. Toda implementação deve ocorrer neste repositório e manter seu histórico próprio. O aplicativo de referência é somente leitura; nunca o altere, instale dependências nele, execute comandos que modifiquem seus arquivos, crie commits ou publique alterações nele.

## Arquitetura

- Consulte docs/current-state.md, AI_CONTEXT.md e docs/design-system.md antes de mudanças relevantes.
- Consulte a documentação versionada Expo SDK 58 antes de escrever código usando APIs Expo.
- Preserve Expo Router NativeTabs estável, Native Stack, Stack.Toolbar, o plugin Starter de sincronização, @expo/ui/SwiftUI, Liquid Glass, ProgressiveCollapsibleScreen, Progressive Blur e fallbacks.
- Componentes visuais não devem depender de login, rede ou serviços externos.
- Não adicione lógica comercial, dados pessoais, assets do aplicativo de referência ou credenciais.

## Validação

Depois de alterações, executar npm run typecheck, npm run lint e npm test -- --runInBand. Para mudanças nativas, validar também node scripts/verify-starter-native.js e o workflow Swift Preflight. Um resultado estático não comprova o comportamento visual em Simulator/iPhone.

## NativeSim e publicação pública

Starter é a fonte privada da verdade; Starter-NativeSim-Public é espelho unidirecional filtrado. Use scripts/mirror-starter.ps1 e a allowlist documentada. Nunca copie .env, credenciais, certificados, dados pessoais ou histórico Git da fonte. Nunca receba alterações do espelho público de volta ao privado. Antes de publicar, examine o diff e execute a auditoria de segurança incluída.

Não usar force push. Não executar workflow, EAS build, prebuild local ou NativeSim sem solicitação explícita do usuário.
