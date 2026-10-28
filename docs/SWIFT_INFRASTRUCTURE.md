# Barasu: contrato para un cliente Swift

La app nativa vive en `ios/GroceryAI`. Su cliente `GroceryAPIClient` usa `URLSession`, modelos `Codable` y servicios inyectables. El backend conserva Claude, Firecrawl, Supabase y ElevenLabs; ninguna clave de esos proveedores debe entrar al binario iOS.

## Frontera de red

| Necesidad en Swift | API actual | Estado |
| --- | --- | --- |
| Crear y editar borrador | `POST /v1/chat/search`, `action=update_draft` | Cliente nativo integrado |
| Precio de un producto, foto, fuente | `POST /v1/chat/search`, `action=product_prices` | Cliente nativo integrado; `published` y `local` son alcances distintos |
| Comparar un borrador | `POST /v1/chat/search`, `action=compare` | Cliente nativo integrado; requiere evidencia de ubicación para afirmar disponibilidad |
| GPS | CoreLocation y geocodificación nativa | Envía al backend solo el CP que confirmó el usuario |
| Token temporal de voz | `POST /v1/voice/session` | Integrado para simulador/local; el backend bloquea solicitudes remotas sin autenticación |
| Lista semanal por comercio | Búsquedas por artículo + `web/weekly-plan.js` | **Solo web**. Swift aún no tiene contrato ni planificador equivalente |
| Guardados e histórico | SwiftData local | Sin sincronización entre iPhone, web y otros dispositivos |

Los contratos JSON están en `contracts/schema.ts`, sus esquemas en `contracts/*.schema.json` y las respuestas de referencia en `fixtures/`. Las respuestas parciales conservan los faltantes y nunca equivalen a una compra completa. Los precios publicados no prueban inventario local. La app abre fichas del comercio; no crea carritos ni procesa pagos.

## Configuración de red

- Debug en simulador: sin configuración usa `http://127.0.0.1:3000`. El backend se inicia con `npm run build && npm start`.
- Debug en iPhone físico: configurar `BARASU_API_BASE_URL` en Info.plist con el origen HTTPS del backend. `localhost` en el teléfono se refiere al teléfono, no al Mac.
- Release: la misma clave HTTPS es obligatoria. Si falta o es inválida, el cliente muestra un error en vez de intentar `localhost`. No se admite HTTP remoto ni credenciales dentro de la URL.
- La API pública requiere autenticación de usuario, límites por usuario y un despliegue HTTPS antes de habilitar el endpoint de voz para iPhone físico. No se debe quitar el bloqueo loopback como atajo.

La compilación CI ejecuta el build iOS del proyecto. El equipo debe validar en Xcode el permiso When In Use, cancelación de voz en segundo plano, Dynamic Type, VoiceOver y el flujo en un dispositivo antes de distribuir la app.

## Trabajo para paridad de la lista semanal

Para llevar la nueva experiencia web a Swift, definir un contrato versionado de cesta completa desde el servidor o un planificador nativo con las mismas reglas: precio por unidad y paquete, vigencia de fuente, cobertura, una o dos tiendas, cambios de presentación, total parcial y enlace por producto. Las pruebas de ambos clientes deben usar los mismos fixtures. No reutilizar `compare` como si ya ofreciera esa experiencia: hoy valida ubicación de otra forma y devuelve un solo plan. La lógica de `web/weekly-plan.js` y la interfaz de carrusel todavía no son código Swift.
