# Integración iOS

Proyecto existente importado de `feat/ios`, commit
`9243aa01a80a80542c2bfa7f9cb3bbe6bc8479ba`. No es una segunda app.

Abrir `GroceryAI.xcodeproj` en Xcode con SDK iOS 26 / compilador Swift 6.2 o posterior.
`SWIFT_VERSION=6.0` es el modo de lenguaje Swift 6; no selecciona la versión instalada del compilador.
Elegir un simulador iOS 26 y ejecutar. El proyecto no necesita firma para simulador.

`Data/API/GroceryAPIClient.swift` contiene la única URL base configurable para
borrador, precios y comparación. La voz usa el mismo valor. Debug sin configuración
conecta a `http://127.0.0.1:3000` para el simulador. Release exige la clave
`BARASU_API_BASE_URL` en Info.plist con un origen HTTPS; si falta, la app presenta
un error de configuración en lugar de apuntar silenciosamente al propio teléfono.
Para un iPhone físico se necesita un backend HTTPS alcanzable y autenticación de
usuarios antes de habilitar voz fuera de loopback.

Cambios de integración:
- Servicios HTTP reales por defecto; mocks solo para previews/pruebas.
- Un POST con tres acciones (borrador, comparación y búsqueda de precios); notes:null se serializa explícitamente. Los tres flujos usan servicios inyectables para probar el cliente sin red.
- Timeout de red 95 s, validación de respuesta y cantidades, manejo de error sin perder borrador.
- Mapeo de JSON snake_case a modelos existentes, precios, fechas y fuentes.
- Advertencias de respuestas parciales visibles; solo se guarda una comparación completa.
- Historial inicial vacío; no se inventan compras previas.
- Cambiar borrador invalida el resultado anterior.
- Localización When In Use, reverse geocoding a CP mexicano, timeout 20 s y entrada manual.
  Solo se transmite CP; no se envían coordenadas.

La app integrada **compila en GitHub Actions**, run 40621570223, con destino genérico
iOS Simulator y sin firma. No hay Xcode local y todavía no se probó la interacción
en un simulador/dispositivo. También se validaron sintaxis Swift y formato del proyecto.
El SDK macOS de CommandLineTools también falla al importar CoreFoundation en este
entorno, por lo que no se declara validación de tipos Swift.

Prueba de aceptación:
1. Enviar «Agrega 2 litros de leche, 12 huevos y 1 kg de arroz».
2. Editar y conservar las cantidades, comparar con CP 06700.
3. Ver dos tiendas, total demo $134, fuentes/fechas y aviso demo.
4. Guardar, repetir desde historial y comprobar que el pedido anterior permanece igual.
5. Probar CP manual y permiso de ubicación denegado.
6. Detener backend para verificar error y recuperación; probar Dynamic Type,
   VoiceOver y ambos temas antes de marcar terminado.


## Barasu: ubicación y ahorro

`BARASU_API_BASE_URL` en Info.plist permite configurar el servidor. El valor por
omisión 127.0.0.1 sirve al simulador; en un iPhone físico usar un backend HTTPS
accesible. No incluir claves de Claude, Firecrawl ni service_role en la app.

Ubicación puntual con permiso When In Use, rechazo de posiciones de más de 60 s,
indicación de precisión aproximada, cancelación de solicitudes y CP manual.
El usuario confirma el CP antes de usarlo. No hay seguimiento en segundo plano.
Solo el CP llega al servidor. Tener GPS no confirma cobertura ni inventario de tiendas.

Las ofertas reales permiten añadir presentaciones y declarar el precio habitual de
la misma presentación. Cesta estimada y compras confirmadas son entidades distintas.
Para registrar ahorro se solicita el importe realmente pagado, excluyendo envío y
otros artículos. Se conserva una instantánea, se impiden confirmaciones repetidas,
y una diferencia negativa no se recorta a cero. Si falta una referencia, la compra
queda registrada sin incluirse en el ahorro. Persistencia SwiftData local; no se
sincroniza con la web ni entre dispositivos.

Verificación 2026-10-27: GitHub Actions run 40632753752 pasó build iOS y prueba Swift
del cálculo, importes decimales, diferencia negativa, duplicados y serialización.
La web pasó 58 tests y prueba visual con búsqueda real de Axe: 2 × $84, precio
habitual de prueba $100, total pagado de prueba $170 => diferencia registrada $30.
La recarga conserva la compra. La ubicación real y los permisos aún requieren una
prueba física en iPhone. La validación local de existencias sigue limitada por las
respuestas y verificaciones de cada supermercado.
