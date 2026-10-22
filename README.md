# Starter

Template visual independente para aplicativos React Native com Expo SDK 58. A base demonstra navegação e controles nativos do iOS, sem autenticação, rede, banco remoto ou regras de negócio.

## O que vem incluído

- Expo Router com NativeTabs estável e Native Stack.
- Stack.Toolbar compartilhada e sincronização das toolbars no iOS.
- Títulos grandes/compactos, animação de scroll e Progressive Blur.
- Controles SwiftUI via @expo/ui, incluindo Bottom Sheet e Context Menu.
- Liquid Glass real quando suportado, com fallbacks para Expo Go, Android e Web.
- Tema claro/escuro, tokens, Reanimated e feedback tátil.
- Quatro abas demonstrativas e uma tela secundária fictícia.

## Começar localmente

Requisitos desta versão: Node.js 22.13 ou mais recente, Xcode 26.4 ou mais recente para compilar iOS e CocoaPods instalado. O alvo mínimo de iOS é 16.4.

    npm ci
    npx expo install --check
    npx expo-doctor
    npm run start

O Metro e os fallbacks funcionam em Expo Go. Os controles SwiftUI e o plugin de sincronização de toolbar precisam de um Development Build para validação nativa real.

## Validar alterações

    npm run typecheck
    npm run lint
    npm test -- --runInBand
    node scripts/verify-starter-native.js

Não declarar o comportamento visual nativo validado até executar o app em iOS Simulator ou iPhone.

## Criar outro aplicativo

Use o Starter como base e mantenha o novo app em outra pasta e repositório. Para criar um clone com remoto próprio:

```powershell
gh auth status
gh repo create LuanRigatti/MeuApp --private
git clone https://github.com/LuanRigatti/Starter.git C:\Projetos\MeuApp
git -C C:\Projetos\MeuApp remote set-url origin https://github.com/LuanRigatti/MeuApp.git
git -C C:\Projetos\MeuApp push -u origin main
```

Esse fluxo mantém a linhagem de commits do Starter. Se precisar de histórico inicial separado, crie o repositório a partir de um template GitHub habilitado ou copie os arquivos para um repositório vazio antes do primeiro commit.

Antes de desenvolver o app novo, ajuste `name`, `slug`, `scheme`, `ios.bundleIdentifier`, `android.package`, `package.json`, ícones, splash, textos e rotas. Crie um EAS project próprio somente se for usar EAS; nunca reutilize IDs ou credenciais de outro app.

O Starter contém automações específicas para `C:\Projetos\Starter` e `LuanRigatti/Starter-NativeSim-Public`. Antes de publicar um app derivado, remova ou adapte `.github/`, `.agents/skills/` e os scripts `mirror-starter`, `Start-StarterNativeSim`, `Invoke-StarterSwiftPreflight` e `Download-StarterSimulatorArchive`. Não os use para apontar o app novo aos repositórios do Starter.

## EAS independente

O arquivo eas.json contém perfis apenas para Simulator. O projeto não fica vinculado ao EAS por padrão. Para usar EAS, crie um projeto separado para Starter e configure `EXPO_TOKEN` e a variável `EAS_PROJECT_ID` no repositório. O workflow injeta esse ID somente por `STARTER_EAS_PROJECT_ID` e valida bundle ID e perfil Simulator antes de solicitar o build.

## Espelhamento e NativeSim

O Starter privado é a fonte da verdade. O espelho público é atualizado em uma direção, por allowlist e com auditoria de segurança:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\mirror-starter.ps1
    git -C C:\Projetos\Starter-NativeSim-Public diff --cached --check
    git -C C:\Projetos\Starter-NativeSim-Public diff --cached
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\mirror-starter.ps1 -Publish

A skill `mirror-starter` descreve revisão do diff e publicação. A skill `starter-nativesim` executa Swift Preflight no SHA público exato e inicia o streaming. A skill `starter-swift-preflight` executa o gate isoladamente. A skill `starter-simulator-archive` compila, exporta e valida o `.app.tar.gz` do run atual.

Para executar somente Swift Preflight:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarterSwiftPreflight.ps1

Para iniciar uma sessão NativeSim (o launcher executa Swift Preflight antes):

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-StarterNativeSim.ps1 -Minutes 30

Para compilar com exportação `.app.tar.gz`:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-StarterNativeSim.ps1 -Minutes 30 -ExportArchive

Depois da conclusão do CLI, use o ID numérico presente na URL do GitHub Actions para baixar uma cópia verificada:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Download-StarterSimulatorArchive.ps1 -RunId <RUN_ID>

O artefato é um arquivo .app.tar.gz, preservado como tar para manter permissões e symlinks. A retenção é de um dia. Os arquivos YAML declaram `workflow_dispatch`; nenhuma sessão ou compilação deve começar sem pedido explícito.

Na preparação inicial, o GitHub registrou alguns checks de `push` no Starter privado como falhas sem jobs, sem check runs e sem logs. Nenhum runner ou build começou. Esses registros não apareceram no espelho público; confira a aba Actions antes do primeiro dispatch manual.

## Conteúdo demonstrativo

Os textos e cartões das telas são fictícios e ficam em código local. A aba Buscar filtra somente essa lista de exemplo. Nenhuma ação salva imagens, links, textos ou arquivos.
