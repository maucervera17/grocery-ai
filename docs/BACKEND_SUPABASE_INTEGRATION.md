# Barasu: conexión de clientes, backend y Supabase

Guía de incorporación para otro agente o desarrollador. Estado del repositorio al 28 de octubre de 2026. Para resolver diferencias con documentos históricos, consulta primero el código y los contratos citados aquí.

## Arquitectura actual

```text
Web / iOS ──HTTP JSON──> Fastify (backend/app.ts, backend/server.ts)
                            ├─> Claude Haiku 5.5: interpreta texto y edita borrador
                            ├─> Firecrawl: busca y lee fichas de Chedraui,
                            │   Bodega Aurrera y Walmart
                            ├─> Supabase PostgREST RPC: catálogo y precios
                            ├─> ElevenLabs Agents: token temporal para voz
                            └─> Nominatim: coordenadas a CP, con confirmación
```

Los clientes **no se conectan directamente a Supabase**. El backend usa `service_role` únicamente en el servidor. No hay autenticación de usuario en este prototipo; no expongas el backend público sin añadirla. El backend no guarda borradores ni historial personal. La web guarda borrador, wishlist, lista semanal y ahorro en `localStorage`; iOS guarda su estado local con SwiftData. La base guarda catálogo, última observación de precio e historial de precios, no compras efectuadas.

## Arranque desde un clon

### URLs concretas y alcance

| Servicio | URL | Quién puede usarla |
| --- | --- | --- |
| Proyecto Supabase Barasu | `https://vlfqqniorpfveuxhqnpt.supabase.co` | **Solo el backend** con su `SUPABASE_SERVICE_ROLE_KEY` secreta. Es el valor de `SUPABASE_URL` en `.env.example`. |
| API Barasu local | `http://127.0.0.1:3000` | Web y simulador iOS que corren **en el mismo Mac** que el backend. |
| Salud | `http://127.0.0.1:3000/health` | Comprueba el proceso local; no comprueba acceso remoto a proveedores. |
| Búsqueda y comparación | `http://127.0.0.1:3000/v1/chat/search` | Cliente local que llama a Fastify, nunca a Supabase directamente. |
| API pública para otro Mac o iPhone físico | **No existe todavía** | Hace falta desplegar un backend HTTPS con autenticación y configurar su URL base en el cliente. `127.0.0.1` en otro dispositivo apunta a ese dispositivo, no a este Mac. |

La URL de Supabase no sustituye la URL de la API Barasu: las RPC requieren una clave privilegiada que jamás debe enviarse a iOS o al navegador. Si otro agente solo necesita compilar o probar la app en su propio Mac, debe iniciar el backend allí y usar `http://127.0.0.1:3000`; si necesita usar **este** backend desde otro equipo, aún no hay un endpoint remoto seguro para ello.

```sh
npm ci                       # Node.js 22+
cp .env.example .env          # .env está ignorado por Git
npm run dev                   # http://127.0.0.1:3000
curl http://127.0.0.1:3000/health
```

`DATA_MODE=demo` funciona sin proveedores y marca los datos como demo. Para conectar la base existente y consultar fuentes reales, configura **solo en `.env` del backend**:

| Variable | Función |
| --- | --- |
| `DATA_MODE=live` | Evita usar los fixtures demo como resultados reales. |
| `SUPABASE_URL` | URL HTTPS del proyecto Barasu: `https://vlfqqniorpfveuxhqnpt.supabase.co`. |
| `SUPABASE_SERVICE_ROLE_KEY` | Clave secreta del servidor; jamás en Swift, JS del navegador, Git o logs. |
| `FIRECRAWL_API_KEY` | Clave REST para consultas de fichas; el login MCP no la configura. |
| `ANTHROPIC_API_KEY` + `CLAUDE_MODEL` | Agente de texto directo. El ejemplo usa `claude-haiku-5-5`. |
| `AI_GATEWAY_API_KEY` + `AGENT_MODEL` | Alternativa a Anthropic directo; si hay ambas configuraciones, `backend/server.ts` elige Anthropic. |
| `ELEVENLABS_API_KEY` + `ELEVENLABS_AGENT_ID` | Voz. La API key se queda en el servidor; el cliente recibe un token temporal. |
| `HOST`, `PORT` | Por defecto `127.0.0.1:3000`, accesible desde ese Mac. |

La referencia del proyecto remoto **no es una credencial**. Cada integrante debe obtener acceso al proyecto y su propia configuración segura. No distribuyas valores de `.env` por Git o chat.

`GET /health` devuelve `mode` y si `agent`, `firecrawl` y `database` están **configurados**. No prueba que sus servicios remotos respondan. Para probar la base, usa `npm run smoke:db` con la URL y clave adecuadas; este comando escribe filas demo y confirma lectura, idempotencia y separación demo/live. No lo ejecutes contra una base ajena sin revisar ese efecto.

## Contrato HTTP para web y Swift

La fuente de verdad es `contracts/schema.ts`. `npm run contracts` genera `contracts/chat-search.request.schema.json` y `contracts/chat-search.response.schema.json`. Los cuerpos de ejemplo están en `fixtures/`. Respuestas: `reply`, `status` (`complete`, `partial`, `error`), `draft_items`, `plan`, `errors` y, para precio individual, `comparison`. Los importes son **centavos MXN**; fechas en ISO 8601; los nombres JSON son `snake_case` salvo el objeto `listing`, que usa los campos de `ScrapedListing` en `camelCase`.

| Ruta | Uso |
| --- | --- |
| `POST /v1/chat/search`, `action: update_draft` | Enviar `message` y `items` actuales; Claude devuelve operaciones validadas y el nuevo `draft_items`. Mantener IDs existentes. |
| `POST /v1/chat/search`, `action: product_prices` | Pregunta sobre **un** producto; `items: []`. `price_scope: published` da precios publicados, `local` exige `location` y evidencia de CP. Devuelve `comparison.offers`, fotos/enlaces opcionales y ganador cuando es comparable. No modifica el borrador. |
| `POST /v1/chat/search`, `action: compare` | Enviar `items` y opcionalmente `location`, `preferences.max_stores` 1 o 2. Devuelve un `plan` con tiendas, líneas, totales, faltantes y ahorro estimado si hay referencia válida. |
| `POST /v1/location/resolve` | Enviar `{latitude, longitude}`; devuelve `postal_code`, `area` y `requires_confirmation`. El usuario debe confirmar el CP sugerido. |
| `GET /v1/voice/status` | Indica si ElevenLabs está configurado. |
| `POST /v1/voice/session` | Entrega token temporal para ElevenLabs; por ahora restringido a loopback. |

Ejemplo mínimo de consulta de un producto:

```sh
curl -s http://127.0.0.1:3000/v1/chat/search \
  -H 'Content-Type: application/json' \
  -d '{"action":"product_prices","message":"¿Dónde está más barato el queso Oaxaca?","items":[],"price_scope":"published"}'
```

Para una lista, llama primero `update_draft`, conserva `draft_items` con sus `client_item_id`, deja que el usuario revise cantidades y luego llama `compare` con esos mismos elementos. `notes` debe estar presente como texto o `null`; `category_id` es opcional en el borrador. En el plan, cada tienda tiene `retailer_id` (`chedraui`, `bodega_aurrera`, `walmart` o `unknown`) y `retailer_name`; el campo `retailer` permanece temporalmente para el cliente web. Cada línea tiene `category_id`, incluso si el borrador no lo envió. Un `status: partial` puede contener resultados útiles y advertencias; un HTTP 200 por sí solo no garantiza datos verificados. Consulta `contracts/api.md` para semántica de unidades, ahorro, errores y procedencia.

## Supabase: esquema, RPC y migraciones

El esquema canónico está en `database/migrations/`; `supabase/migrations` es un enlace a esa carpeta, no otra copia. Orden:

1. `202610280001_catalog.sql`: `retailers`, `stores`, `products`, `listings`, `prices`, `price_history`; funciones RPC y RLS.
2. `202610280002_catalog_consistency.sql`: consistencia y seguridad del catálogo.
3. `202610280003_postal_evidence.sql`: `listings.location_evidence` y RPC actualizadas.
4. `202610280004_product_images.sql`: `listings.image_url` y RPC actualizadas para fotos.

`backend/supabase-repository.ts` es el único adaptador DB. Usa PostgREST `POST /rest/v1/rpc/grocery_search_listings` con `p_query`, `p_postal_code`, `p_limit`, `p_demo`, y `POST /rest/v1/rpc/grocery_upsert_listings` con `p_listings`, `p_postal_code`, `p_demo`. Envía `apikey` y `Authorization: Bearer` desde el servidor. Las RPC y tablas están restringidas a `service_role`; no implementes acceso directo desde una app cliente usando esa clave. `listings` separa los datos por código postal y `is_demo`; el backend verifica que una observación local tenga evidencia de CP/modalidad/stock y sea reciente. El CP por sí solo no prueba disponibilidad de una sucursal.

Las migraciones 001–004 se aplicaron al proyecto remoto mediante SQL Editor. **Ese método no actualiza el historial de migraciones de Supabase CLI**. Antes de `supabase db push`, inspecciona el esquema remoto y reconcilia el historial con `supabase migration repair` desde una cuenta con acceso; no reinicies ni reapliques a ciegas la base compartida. La migración de imágenes se comprobó con lectura API y RPC, pero cada nuevo entorno debe verificar sus propias columnas y funciones. El seed demo está en `database/seed/demo.sql` y no debe presentarse como precio real.

Para una base local de desarrollo, sigue `database/README.md` y `supabase/config.toml`. Para comprobar la integración sin escribir en Supabase remoto, usa las pruebas unitarias y los fixtures; para comprobar el proyecto real, revisa primero el efecto de `npm run smoke:db` indicado arriba.

## Integración iOS y límites actuales

`ios/GroceryAI/Data/API/GroceryAPIClient.swift` contiene `APIConfiguration.baseURL` (actualmente `http://127.0.0.1:3000`) y el cliente tipado. El simulador en el mismo Mac puede usar esa URL. Un iPhone físico necesita un backend HTTPS accesible, configuración de red/ATS correspondiente y autenticación antes de exposición pública. El cliente iOS actual implementa `update_draft` y `compare`; el contrato backend también tiene `product_prices`, pero no presupongas que la UI nativa ya lo llama. La foto de cada línea de plan está en `image_url` opcional. La geolocalización iOS usa CoreLocation/CLGeocoder y envía CP, no coordenadas al backend.

La voz web usa ElevenLabs con `gpt-4.1-mini` y `eleven_flash_v2_5` en el agente configurado; la configuración versionada está en `config/elevenlabs-agent.json`. El endpoint de sesión local no habilita por sí solo voz en un iPhone físico. El historial de ahorro y wishlist no tienen sincronización multiusuario por Supabase. Tampoco hay creación automática de un carrito externo: los enlaces llevan a las tiendas para que el usuario finalice allí.

## Verificación y diagnóstico

```sh
npm run contracts
npm run typecheck
npm test
npm run build
# Con .env de Supabase y tras revisar que escribe seed demo:
npm run smoke:db
```

- Si `/health` dice `database: unconfigured`, revisa solo las variables del servidor y reinícialo.
- Si hay HTTP 200 con `status: partial`, lee `errors[]`, `unmatched_items` y el alcance `published/local`; no ocultes el fallo de una tienda.
- Si falta una foto, `imageUrl`/`image_url` es opcional; muestra respaldo neutro y verifica que la migración 004 exista en ese entorno.
- Si cambia un CP, descarta resultados previos del cliente. No reutilices una observación `published` como disponibilidad local.
- Si la voz falla, consulta `/v1/voice/status`; la sesión solo acepta loopback por diseño y requiere ambas variables de ElevenLabs.

Archivos de referencia: `backend/server.ts`, `backend/app.ts`, `backend/service.ts`, `backend/product-prices.ts`, `backend/supabase-repository.ts`, `scrapers/firecrawl.ts`, `contracts/schema.ts`, `database/migrations/`, `ios/GroceryAI/Data/API/GroceryAPIClient.swift`.
