# Acceso e integración para otro agente de Barasu

Esta es la entrada para quien clone el repositorio o conecte un cliente nuevo. Las URLs y los contratos sí se comparten por Git; las contraseñas y claves se obtienen por acceso autorizado a cada servicio, nunca de este repositorio.

## Servicios y permisos

| Recurso | Dirección | Acceso necesario |
| --- | --- | --- |
| Código y contratos | [GitHub: maucervera17/grocery-ai](https://github.com/maucervera17/grocery-ai) | Permiso al repositorio para clonar y proponer cambios. |
| API desplegada | `https://barasu-api.onrender.com` | `GET /health` es público. Las demás rutas requieren HTTP Basic: usuario `barasu` y la contraseña vigente de `BARASU_ACCESS_PASSWORD`, compartida por el responsable mediante un gestor de secretos. |
| Servicio y despliegues | [Render: barasu-api](https://dashboard.render.com/web/srv-dbh6k7flk1mc73fdlb4g) | Invitación al workspace/proyecto de Render para ver logs o cambiar variables. El servicio gratuito se despliega automáticamente desde `main`. |
| Proyecto de datos | [Supabase: Barasu](https://supabase.com/dashboard/project/vlfqqniorpfveuxhqnpt) | Invitación al proyecto Supabase para ver esquema y SQL Editor. Su URL API es `https://vlfqqniorpfveuxhqnpt.supabase.co`, **no** la URL que usa iOS. |
| Firecrawl | [Consola Firecrawl](https://firecrawl.dev/app) | Acceso a la cuenta o a una clave REST propia para ejecutar scraping desde el backend. El login MCP no configura `FIRECRAWL_API_KEY`. |
| ElevenLabs | [Consola ElevenLabs](https://elevenlabs.io/app) | Acceso al agente y a una clave limitada si se va a administrar voz. iOS nunca recibe la clave del proveedor. |

Si falta acceso a una cuenta, pide al responsable del proyecto una invitación para esa cuenta. GitHub no concede por sí mismo permisos en Render, Supabase, Firecrawl ni ElevenLabs. No copies `.env` ni valores del panel de Render a una issue, PR, chat, archivo Swift o documentación.

## Conectar un cliente a la API existente

1. Base URL: `https://barasu-api.onrender.com` (sin `/v1` al final). HTTPS es obligatorio en un iPhone físico.
2. Comprueba `GET /health`. Responde con `status`, `mode` y si `agent`, `firecrawl` y `database` están **configurados**; no prueba que una consulta a cada proveedor tenga éxito.
3. Para las rutas protegidas usa HTTP Basic sobre HTTPS con usuario `barasu` y la contraseña actual. `curl -u barasu` solicita la contraseña de forma interactiva y evita escribirla en el comando:

   ```sh
   curl -u barasu https://barasu-api.onrender.com/v1/voice/status
   curl -u barasu -H 'Content-Type: application/json' \
     --data-binary @fixtures/compare.request.json \
     https://barasu-api.onrender.com/v1/chat/search
   ```

4. Para crear una lista mediante lenguaje natural, envía `POST /v1/chat/search` con `action: "update_draft"`, `message` e `items` actuales. Conserva los `client_item_id` de `draft_items`; luego envía `action: "compare"` con esos elementos, `location.postal_code` y `preferences.max_stores` de 1 o 2. Para un solo producto usa `action: "product_prices"` y `price_scope: "published"` o `"local"`. El alcance local requiere ubicación y evidencia de tienda.
5. Lee `status`, `errors`, `unmatched_items`, alcance y fecha además del HTTP status. Los importes son centavos MXN. Una respuesta parcial puede tener ofertas útiles sin confirmar existencias para el CP; no la presentes como compra disponible.

El contrato tipado está en [`contracts/schema.ts`](../contracts/schema.ts), su descripción en [`contracts/api.md`](../contracts/api.md), los JSON Schema y peticiones de ejemplo en [`contracts/`](../contracts/) y [`fixtures/`](../fixtures/). Las rutas completas están en [`BACKEND_SUPABASE_INTEGRATION.md`](BACKEND_SUPABASE_INTEGRATION.md).

### iOS y voz

La app iOS ya usa la URL HTTPS de Render en `ios/GroceryAI/Data/API/GroceryAPIClient.swift`. El usuario introduce la contraseña de demo en **Agente → Ajustes → Backend**; se guarda en Keychain y se usa para chat y `POST /v1/voice/session`. El servidor entrega un token temporal de ElevenLabs, no su API key. `VoiceConversationController.swift` registra el manejador de la herramienta cliente `barasu_search`. La ubicación se obtiene con CoreLocation y se envía al backend como código postal confirmado; no se envían coordenadas al endpoint de búsqueda.

La contraseña Basic es compartida y temporal: permite la demo privada, pero no identifica a cada usuario. Antes de distribuir la app fuera del equipo, se necesita autenticación individual, límites por usuario y controles de costos. El plan gratuito de Render puede tardar en responder tras inactividad.

## Ejecutar el backend local

```sh
git clone https://github.com/maucervera17/grocery-ai.git
cd grocery-ai
npm ci                       # Node.js 22+
cp .env.example .env
npm run dev                   # http://127.0.0.1:3000
curl http://127.0.0.1:3000/health
```

`DATA_MODE=demo` no necesita credenciales y etiqueta los precios ficticios. Para `DATA_MODE=live`, configura en el `.env` local las claves autorizadas de Anthropic, Firecrawl y Supabase; para voz, también `ELEVENLABS_API_KEY` y `ELEVENLABS_AGENT_ID`. Consulta [`.env.example`](../.env.example) para todos los nombres. En Render, esas variables están en **Environment**; el archivo local no se sincroniza con Render. `BARASU_ACCESS_PASSWORD` protege un servidor live expuesto fuera de loopback y debe tener al menos 24 caracteres.

El cliente llama solamente al backend. `SUPABASE_SERVICE_ROLE_KEY` se usa exclusivamente en `backend/supabase-repository.ts`; no debe aparecer en apps ni navegador. Las migraciones 001–004 están en [`database/migrations/`](../database/migrations/) y ya se aplicaron al proyecto compartido mediante SQL Editor. Ese proceso no actualiza el historial de Supabase CLI: **no ejecutes `supabase db push`** sin revisar y conciliar antes el historial remoto. `npm run smoke:db` escribe filas demo en Supabase; revisa ese efecto antes de ejecutarlo.

## Verificación y diagnóstico

```sh
npm run contracts
npm run typecheck
npm test
npm run build
```

- `401`: falta o es incorrecta la contraseña Basic. En iOS actualízala en Ajustes; no metas la contraseña en el código.
- `503` en `/v1/voice/session`: faltan las variables de ElevenLabs en el servidor. `429`: se superó el límite de sesiones por IP.
- `status: partial` o errores de fuente: inspecciona `errors[]` y el alcance de precio; Firecrawl puede no confirmar disponibilidad para la ubicación.
- `/health` no sustituye una prueba de búsqueda o voz autenticada. Comprueba la ruta real antes de reportar la integración como funcional.
- Para cambios de API, actualiza los contratos y fixtures y ejecuta las cuatro comprobaciones anteriores antes de proponer un PR.

Más detalles operativos: [`RENDER_DEPLOYMENT.md`](RENDER_DEPLOYMENT.md), [`BACKEND_SUPABASE_INTEGRATION.md`](BACKEND_SUPABASE_INTEGRATION.md) y [`VOICE_LOCATION_WISHLIST.md`](VOICE_LOCATION_WISHLIST.md).
