# Sistema de diseño de Barasu para iOS

## 1. Propósito

Este documento define el sistema visual y de interacción de la aplicación Barasu para iOS. Su objetivo es permitir que otro agente implemente pantallas nuevas o copie el lenguaje visual sin depender de imágenes de referencia.

La implementación actual en SwiftUI es la fuente de verdad. Los tokens se encuentran en `ios/GroceryAI/Core/DesignSystem`. La aplicación requiere iOS 26 y utiliza APIs nativas de SwiftUI.

## 2. Principios

1. Usar componentes nativos antes de crear controles personalizados.
2. Mantener las vistas ligeras. Mostrar únicamente la información necesaria para tomar una decisión.
3. Reservar el azul para acciones, selección y estados informativos.
4. Usar fondos y tarjetas neutros. No teñir las superficies de verde, especialmente en modo oscuro.
5. Reservar Liquid Glass para controles flotantes e interactivos. Las tarjetas de contenido son superficies sólidas.
6. Mantener paridad visual entre modo claro y oscuro.
7. Usar texto breve, literal y en español de México.
8. Usar SF Symbols para acciones y estados. No agregar ilustraciones decorativas sin una función clara.

## 3. Marca

### 3.1 Nombre

El nombre visible de la aplicación es **Barasu**.

### 3.2 Recursos

- Wordmark adaptativo: `BrandLaunchLogo.imageset`.
- Wordmark claro: `barasu-light.svg`.
- Wordmark oscuro: `barasu-dark.svg`.
- Recursos vectoriales de marca: `ios/GroceryAI/Resources/Brand`.
- Icono de aplicación: `ios/GroceryAI/barasu-icon.icon`.

El wordmark oscuro usa letras blancas. El wordmark claro usa el verde primario. Los dos puntos azules se conservan en ambos modos.

### 3.3 Avatar del agente

El agente usa el wordmark dentro de un círculo de 44 puntos:

- Modo claro: círculo negro y logo adaptado al fondo oscuro.
- Modo oscuro: círculo blanco y logo adaptado al fondo claro.
- Padding interior: 8 puntos.

No usar el símbolo `sparkles` como avatar de Barasu.

## 4. Color

### 4.1 Paleta de marca

| Token | Hex | Uso |
|---|---:|---|
| `primary` | `#0B2220` | Texto de marca y confianza |
| `accent` | `#0066FF` | Acciones, selección e información |
| `success` | `#22C55E` | Éxito y disponibilidad |
| `alert` | `#FACC15` | Advertencias y sustituciones |
| `neutral` | `#E5E7EB` | Bordes claros |
| `surface` | `#F9FAFB` | Fondos secundarios claros |

Fuente: `BarasuPalette.swift`.

### 4.2 Colores semánticos en modo claro

| Token | Valor |
|---|---|
| `brandPrimary` | `#0066FF` |
| `brandOnPrimary` | Blanco |
| `brandSecondary` | Azul al 10 % |
| `backgroundPrimary` | Blanco |
| `backgroundSecondary` | `#F9FAFB` |
| `cellBackground` | `#F9FAFB` |
| `surfacePrimary` | Blanco |
| `surfaceElevated` | `#F9FAFB` |
| `textPrimary` | `#0B2220` |
| `textSecondary` | `#0B2220` al 64 % |
| `borderSubtle` | `#E5E7EB` |
| `statusError` | Aproximadamente `#B81F21` |

### 4.3 Colores semánticos en modo oscuro

En modo oscuro se usan colores dinámicos del sistema para conservar superficies neutrales:

| Token | Valor SwiftUI |
|---|---|
| `backgroundPrimary` | `Color(uiColor: .systemBackground)` |
| `backgroundSecondary` | `Color(uiColor: .secondarySystemBackground)` |
| `cellBackground` | `Color(uiColor: .secondarySystemBackground)` |
| `surfacePrimary` | `Color(uiColor: .systemBackground)` |
| `surfaceElevated` | `Color(uiColor: .tertiarySystemBackground)` |
| `textPrimary` | `.primary` |
| `textSecondary` | `.secondary` |
| `borderSubtle` | `Color(uiColor: .separator)` |
| `statusError` | Aproximadamente `#FF7A7A` |

El azul de marca, el verde de éxito y el amarillo de advertencia se conservan. No convertir las tarjetas o fondos en superficies verdes.

### 4.4 Acceso al tema

Las vistas deben obtener colores semánticos desde el ambiente:

```swift
@Environment(\.appTheme) private var theme
@Environment(\.colorScheme) private var colorScheme

var body: some View {
    let colors = theme.colors(for: colorScheme)
    // Usar colors.surfacePrimary, colors.textSecondary, etc.
}
```

No usar directamente la paleta de marca para fondos o texto, excepto en componentes de marca y tintes globales.

## 5. Tipografía

Barasu usa la tipografía del sistema de iOS. No carga Inter ni otra fuente externa. Esto conserva Dynamic Type y consistencia nativa.

| Rol | SwiftUI |
|---|---|
| Título de pantalla | `.largeTitle` |
| Título de sección | `.title2` |
| Título de tarjeta | `.headline` |
| Texto principal | `.body` |
| Texto auxiliar | `.callout` |
| Acción | `.headline` |

Reglas:

- Usar `.secondary` para contenido auxiliar.
- Usar `.caption` únicamente para metadatos breves, por ejemplo hora o cantidad de productos.
- Evitar párrafos largos en tarjetas.
- No fijar tamaños tipográficos en puntos.
- Usar `bold()` o estilos semánticos antes de asignar pesos arbitrarios.

## 6. Espaciado y radios

### 6.1 Escala de espaciado

| Token | Puntos |
|---|---:|
| `extraSmall` | 4 |
| `small` | 8 |
| `medium` | 12 |
| `large` | 16 |
| `extraLarge` | 24 |
| `section` | 32 |

### 6.2 Radios

| Token | Puntos | Uso |
|---|---:|---|
| `small` | 8 | Elementos compactos |
| `medium` | 12 | Celdas, campos e imágenes |
| `large` | 18 | Tarjetas y burbujas |
| `capsule` | 1000 | Compatibilidad; preferir `.capsule` |

### 6.3 Tamaños de controles

- Área táctil mínima: 44 × 44 puntos.
- Composer del chat: 52 puntos de alto.
- Avatar del agente: 44 × 44 puntos.
- Miniatura estándar de producto: 48 × 48 puntos en filas.
- Logo de supermercado: 48 × 32 puntos.

No reducir controles interactivos por debajo de 44 puntos.

## 7. Superficies y tarjetas

### 7.1 Tarjeta principal

`SurfaceCard` es la tarjeta estándar:

- Fondo: `surfacePrimary`.
- Radio: 18 puntos.
- Padding predeterminado: 16 puntos.
- Borde: `borderSubtle`, 1 punto.
- Sin sombra.

Modo claro y oscuro conservan la misma estructura: superficie primaria más borde sutil.

```swift
SurfaceCard {
    VStack(alignment: .leading, spacing: AppSpacing.medium) {
        Text("Título").font(.headline)
        Text("Contenido").foregroundStyle(.secondary)
    }
}
```

### 7.2 Celdas

Las listas de productos usan celdas separadas, no filas divididas visualmente:

- Fondo: `cellBackground`.
- Radio: 12 puntos.
- Padding: 12 puntos.
- Separación exterior: 8–12 puntos.
- Imagen cuadrada a la izquierda.
- Nombre y cantidad en el centro.
- Acción o valor secundario a la derecha.

Las celdas de compras anteriores son completamente táctiles. El chevron indica navegación y no debe competir con otro botón dentro de la fila. Acciones secundarias, como repetir, se presentan mediante swipe action, accesibilidad o toolbar del detalle.

## 8. Botones y chips

### 8.1 Acción primaria

- Fondo azul `brandPrimary`.
- Texto blanco `brandOnPrimary`.
- Fuente `.headline`.
- Altura mínima de 44 puntos.
- Radio de 12 puntos en flujos y formularios.
- Puede ocupar todo el ancho.
- Estado deshabilitado con opacidad de 55 %.

### 8.2 Acción secundaria

- Fondo `surfacePrimary`.
- Texto azul.
- Borde `borderSubtle` de 1 punto.
- Misma altura y radio que la acción primaria.

### 8.3 Acción flotante prominente

Las acciones flotantes sobre contenido, como enviar o repetir compra, usan Liquid Glass prominente:

```swift
.glassEffect(
    .regular.tint(colors.brandPrimary).interactive(),
    in: .capsule
)
```

Para botones circulares, usar `.circle`. Los botones adyacentes al composer deben tener la misma altura de 52 puntos.

### 8.4 Chips

- Forma cápsula.
- Altura táctil mínima de 44 puntos.
- Estado normal: superficie primaria, texto primario y borde sutil.
- Estado seleccionado: fondo azul y texto blanco.
- Usar una sola línea y etiquetas breves.

## 9. Liquid Glass

Liquid Glass se usa únicamente donde existe una relación directa con interacción flotante:

- Campo del composer.
- Botón circular de agregar.
- Botón circular de enviar.
- Botón de micrófono.
- Acciones prominentes flotantes sobre el contenido.

No usar Liquid Glass en:

- Tarjetas de productos.
- Historial.
- Comparaciones por tienda.
- Fondos completos.
- Celdas normales.

Agrupar controles relacionados con `GlassEffectContainer`. No envolver toda la barra inferior en una cápsula. El composer se presenta en un `overlay(alignment: .bottom)` y el contenido del chat puede desplazarse detrás de él.

## 10. Navegación y presentación

### 10.1 Estructura

- Raíz: `TabView`.
- Cada pestaña contiene su propio `NavigationStack`.
- Pestañas actuales: Agente e Historial.
- Tinte global: azul `#0066FF`.
- Efecto de scroll edge: `.soft`.

### 10.2 Títulos

- Pantallas principales: `.toolbarTitleDisplayMode(.inlineLarge)`.
- Detalles: `.toolbarTitleDisplayMode(.inline)`.
- Los detalles deben usar un título corto y contextual.
- Cerrar una vista modal con `xmark`, no con texto “Cerrar”, cuando el contexto sea evidente.

### 10.3 Sheets

Usar sheets nativas y `fullScreenCover` o `NavigationStack` según la jerarquía:

- Agregar contenido: 88 % de la pantalla.
- Editar producto: `.medium`.
- Ubicación: `.large`.
- Configuración: `.medium`.
- Mostrar el drag indicator.
- Evitar sheets a pantalla completa si el contenido cabe en una altura parcial.

## 11. Chat y agente

### 11.1 Burbujas

Mensaje del usuario:

- Alineado a la derecha.
- Fondo azul al 10 % en modo claro y 18 % en modo oscuro.
- Sin avatar.

Mensaje del agente:

- Alineado a la izquierda.
- Avatar de Barasu.
- Fondo `surfacePrimary`.
- Borde sutil.

Ambas burbujas usan radio de 18 puntos, padding horizontal de 16 y vertical de 12. La hora aparece como metadato secundario.

### 11.2 Composer

El composer está flotando sobre el chat:

- Botón `+` circular, 52 puntos.
- Campo central Liquid Glass en cápsula.
- Botón de micrófono dentro del campo, a la derecha.
- Botón de enviar circular, 52 puntos, visible solo en modo de texto.
- En modo de voz, reemplazar el campo por un mensaje de estado de una línea.
- No mostrar un medidor o `ProgressView` redundante dentro del campo de voz.
- Limpiar el texto inmediatamente al enviar, aunque la respuesta siga cargando.

El scroll debe reservar espacio real al final para evitar que el contenido quede debajo del composer. Una gradiente neutral se extiende desde el borde inferior y se vuelve transparente hacia arriba. La gradiente usa blanco en modo claro y negro en modo oscuro.

### 11.3 Estados de carga

La actividad del agente se muestra como un mensaje inline del lado del agente. No colocar un indicador flotante encima del chat. Los estados de voz y comparación deben ser breves y específicos.

## 12. Productos e imágenes

### 12.1 Miniaturas

- Formato cuadrado.
- `scaledToFill()`.
- Radio de 12 puntos.
- Fondo secundario neutral.
- Borde sutil de 1 punto.

### 12.2 Respaldo

Si no existe una URL o la imagen falla, mostrar el emoji de la categoría. El emoji es un respaldo, no el origen principal de imagen.

### 12.3 Supermercados

Los supermercados se normalizan mediante `RetailerID`. Usar los recursos incluidos para Walmart, Bodega Aurrera y Chedraui. Un supermercado desconocido usa `storefront` como SF Symbol.

## 13. Lista actual

La lista actual se presenta dentro de una `SurfaceCard`:

- Encabezado con título y cantidad de productos.
- Máximo de cinco productos visibles inicialmente.
- “Ver más” muestra el resto.
- “Ver menos” vuelve al estado compacto.
- Cada producto conserva identidad estable mediante su `UUID`.
- La actualización remota no debe ejecutar animaciones que desplacen repetidamente el chat.
- El botón principal “Comparar precios” aparece al final.

## 14. Historial

El historial usa un control segmentado con Compras y Productos.

- La búsqueda se implementa con `.searchable`.
- Las compras usan tarjetas completamente táctiles.
- Los productos usan celdas redondeadas sin dividers visibles.
- Los estados vacíos usan `ContentUnavailableView`.
- Los detalles de compra usan navegación push y título inline.
- “Repetir compra” se presenta como acción prominente en el overlay inferior del detalle.

## 15. Comparación

- La comparación se abre como `fullScreenCover` con `NavigationStack`.
- El cierre usa `xmark` en la toolbar.
- El título “Comparación” es inline.
- Las tiendas se agrupan en `SurfaceCard`.
- Mostrar logo, nombre, sucursal opcional y subtotal en el encabezado.
- Mostrar advertencias como labels breves con `exclamationmark.triangle`.
- Mostrar el estado de coincidencia con texto, color y símbolo; no depender únicamente del color.
- Una comparación parcial conserva visibles los productos sin coincidencia.
- No permitir “Guardar y terminar” cuando el resultado sea parcial o de error.

## 16. Estados semánticos

| Estado | Color | Uso |
|---|---|---|
| Neutral | `textSecondary` | Metadatos |
| Éxito | `statusSuccess` | Confirmación o coincidencia válida |
| Advertencia | `statusWarning` | Sustitución o revisión necesaria |
| Error | `statusError` | Fallo real |
| Información | `statusInformation` | Estado informativo y demo |

Los badges usan cápsula, texto en negrita y fondo del mismo color al 14 %. Siempre combinar color con texto y SF Symbol.

## 17. Movimiento y actualización

- Usar animaciones únicamente cuando expliquen una transición.
- Usar `.animation(_:value:)` o `withAnimation` con un cambio específico.
- No animar actualizaciones completas de listas provenientes del backend.
- Mantener identidad estable en `ForEach`.
- Evitar desplazar el chat más de una vez por operación.
- Las imágenes pueden usar una transición breve al terminar la descarga.
- Respetar Reduce Motion cuando se agreguen movimientos no esenciales.

## 18. Accesibilidad

- Área táctil mínima de 44 × 44 puntos.
- Compatibilidad con Dynamic Type.
- Iconos decorativos con `accessibilityHidden(true)`.
- Botones de icono con una etiqueta textual completa.
- Celdas complejas combinadas mediante `accessibilityElement(children: .combine)` cuando corresponda.
- Estados seleccionados con `.isSelected`.
- No comunicar coincidencia, sustitución o error únicamente mediante color.
- Usar controles nativos para conservar VoiceOver, teclado y comportamiento del sistema.

## 19. Organización del código

- Un tipo sustancial por archivo.
- Tokens y componentes reutilizables en `Core/DesignSystem`.
- Componentes específicos cerca de la feature que los utiliza.
- Evitar archivos extensos con vistas, modelos y helpers sin relación directa.
- Inyectar `AppTheme` mediante el ambiente.
- Usar nombres semánticos; no crear tokens como `blue1` o `gray2`.

## 20. Lista de verificación para copiar el sistema

1. Copiar `Core/DesignSystem` completo.
2. Copiar `BarasuPalette`, `AppTheme` y `AppThemeColors` sin sustituirlos por colores directos.
3. Instalar `.environment(\.appTheme, .grocery)` en la raíz.
4. Aplicar `.tint(BarasuPalette.accent)` al `TabView`.
5. Aplicar `.scrollEdgeEffectStyle(.soft, for: .all)` en la estructura raíz.
6. Copiar los assets de marca, icono y supermercados.
7. Usar `SurfaceCard`, `PrimaryButton`, `SecondaryButton`, `SuggestionChip` y `StatusBadge` antes de crear variantes.
8. Mantener títulos inlineLarge en pantallas principales e inline en detalles.
9. Usar Liquid Glass únicamente en controles flotantes.
10. Verificar la pantalla en modo claro, modo oscuro, texto grande y VoiceOver.

## 21. Elementos que no deben copiarse

- Diseños tipográficos o pantallas del documento original de marca.
- La fuente Inter como dependencia obligatoria.
- Fondos verdes en modo oscuro.
- Sombras fuertes en tarjetas.
- Dividers entre celdas del historial de productos.
- Barras inferiores personalizadas que dupliquen `TabView`.
- Una cápsula de Liquid Glass que contenga todo el tab bar y el composer.
- Escaneo de productos o códigos de barras.
- Texto “DEMO” o “Demostración” en la interfaz principal.
