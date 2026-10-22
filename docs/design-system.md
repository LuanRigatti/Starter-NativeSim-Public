# Design system do Starter

## Princípios

A identidade de demonstração usa uma paleta independente azul/índigo. Os componentes preservam a estrutura e o comportamento visual reutilizável da origem, sem seus assets, nomes ou cores empresariais.

Use os tokens do ThemeProvider para cor, tipografia, espaçamento, raio, borda, sombra, animação e tamanho. Evite valores avulsos quando um token representar o mesmo papel.

## Tokens de tema

- background, backgroundSecondary, surface, surfaceElevated e surfaceMuted definem superfícies.
- textPrimary, textSecondary, textTertiary e textDisabled definem hierarquia textual.
- primary, secondary, brand e focus definem ênfase e interação.
- success, warning, danger e info são estados visuais genéricos.
- glassSurface e glassBorder servem aos fallbacks de material translúcido.
- darkModeCardSurface e darkModeInsetSurface diferenciam cartões de áreas inseridas no tema escuro.

Light e Dark são derivados do ThemeProvider e seguem a aparência do sistema por padrão. A escolha manual é armazenada apenas localmente com a chave @starter/theme-mode.

## Navegação e títulos

NativeTabs e Native Stack são os donos das transições e gestos. Stack.Toolbar hospeda controles nativos. ProgressiveCollapsibleScreen cuida do título grande, compacto, interpolação no scroll e blur, alinhando o conteúdo com o header nativo.

Não sobrepor controles React Native interativos aos controles SwiftUI. Não restringir animações nativas com clipping ou frames artificiais.

## Materiais e controles

- Liquid Glass vem de expo-glass-effect e @expo/ui quando disponível.
- expo-blur fornece fallback visual quando Liquid Glass não está disponível.
- NativeSheet usa BottomSheet SwiftUI no Development Build, detents configuráveis e drag indicator visível; o fallback usa Gesture Handler e Reanimated.
- NativeCardContextMenu usa o ContextMenu nativo no iOS.
- NativeButton usa Button SwiftUI para manter estado pressionado, haptics e aparência do sistema.
- ProgressiveBlur usa APIs Expo públicas de blur, gradiente e máscara.

## Demonstração

As telas Home, Coleções, Buscar e Ajustes usam texto e cartões fictícios. A tela de detalhe é destinada a validar a navegação nativa, toolbar e swipe-back. Não há fluxo para persistir anexos ou conteúdo.
