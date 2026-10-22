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

A skill `$starter-nativesim` é o fluxo principal: verifica o Starter privado, publica no espelho apenas quando a allowlist e as auditorias passam, reutiliza ou executa Swift Preflight no SHA público exato, inicia uma sessão NativeSim de 120 minutos enviando `export_app=true` e entrega os links assim que ficam disponíveis. A invocação explícita autoriza o push necessário somente ao espelho público. A CLI opera numa cópia temporária com push redirecionado a um repositório local; ela é encerrada antes do seu download local, enquanto o workflow remoto exporta e publica o artifact, instala e abre o Starter e mantém o stream ativo.

A skill `$mirror-starter` continua disponível para preview e publicação independente. A skill `$starter-swift-preflight` executa isoladamente o gate e reutiliza apenas uma aprovação exata. A skill `$starter-simulator-archive` baixa um artifact existente assim que compilação, exportação e upload terminarem, mesmo que a sessão NativeSim ainda esteja ativa; não inicia Preflight, sessão ou nova build.

Para executar somente Swift Preflight:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-StarterSwiftPreflight.ps1

Para iniciar o fluxo completo, use `$starter-nativesim`. O comando direto abaixo é equivalente; a duração omitida é 120 minutos e um valor solicitado pode ser informado entre 1 e 350:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start-StarterNativeSim.ps1

O launcher solicita a geração do archive sem aguardar a compilação, o upload ou o fim da sessão. Assim que os links completos e a identidade do run são verificados, ele encerra o processo local da CLI; o workflow remoto e o túnel permanecem ativos. A chave `k` é entregue somente na resposta privada e nunca é reconstruída ou gravada em logs, workflow, commits ou documentação.

Quando o artifact estiver disponível, localize o run mais recente elegível ou informe seu ID para baixar o arquivo já existente:

    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Download-StarterSimulatorArchive.ps1
    pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\Download-StarterSimulatorArchive.ps1 -RunId <RUN_ID>

O artifact é um arquivo `.app.tar.gz`, preservado como tar para manter permissões e symlinks, com retenção configurada de sete dias (sujeita a um limite menor do repositório/organização). O script de download valida o run, o SHA, as etapas de compilação/exportação/upload e a integridade do tar antes de salvar em `artifacts\<RUN_ID>`. Os workflows declaram `workflow_dispatch`; nenhuma sessão ou compilação começa sem pedido explícito.

Na preparação inicial, o GitHub registrou alguns checks de `push` no Starter privado como falhas sem jobs, sem check runs e sem logs. Nenhum runner ou build começou. Esses registros não apareceram no espelho público; confira a aba Actions antes do primeiro dispatch manual.

## Conteúdo demonstrativo

Os textos e cartões das telas são fictícios e ficam em código local. A aba Buscar filtra somente essa lista de exemplo. Nenhuma ação salva imagens, links, textos ou arquivos.
