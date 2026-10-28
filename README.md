# Barasu — súper semanal, guardados y voz

Nuevo flujo de [lista semanal, conveniencia y ahorro](docs/WEEKLY_SHOPPING.md).

Estado actual y pruebas de wishlist, GPS y ElevenLabs: [guía de integración](docs/VOICE_LOCATION_WISHLIST.md). Las secciones iniciales siguientes conservan documentación histórica del MVP; para ejecutar usa [setup](docs/setup.md).

Backend local TypeScript/Node.js 22+ con Fastify, Zod y Vercel AI SDK. Implementa el acuerdo actualizado: un endpoint, borrador sin estado y comparación de una lista con hasta dos tiendas. Fuentes elegidas: **Chedraui y Bodega Aurrera**.

## Arranque local

```sh
npm ci
cp .env.example .env
npm run dev
```

http://127.0.0.1:3000 — `GET /health` muestra modo y conexiones configuradas. El modo predeterminado es **demo**: parser limitado sin modelo remoto y precios ficticios claramente etiquetados. No requiere credenciales.

```sh
curl -s http://127.0.0.1:3000/v1/chat/search \
  -H 'Content-Type: application/json' \
  -d '{"action":"update_draft","message":"Agrega 2 litros de leche, 12 huevos y 1 kg de arroz","items":[],"location":null}'

curl -s http://127.0.0.1:3000/v1/chat/search \
  -H 'Content-Type: application/json' \
  --data-binary @fixtures/compare.request.json
```

El ejemplo demo devuelve **$134.00 MXN**, con **$6.00 de ahorro ficticio** frente a $140.00 en la mejor tienda única. iOS debe enviar los `draft_items` recibidos como `items` en la comparación y conservar sus IDs. El endpoint no conserva historial ni borradores.

## Agente de lenguaje natural

Configura `AI_GATEWAY_API_KEY` y `AGENT_MODEL` (`provider/model` disponible en tu cuenta). El SDK usa AI Gateway. No se fija un proveedor ni modelo sin elegirlo con el equipo. Si ambas variables están presentes, el agente IA se usa incluso con precios demo; `DATA_MODE=live` exige agente configurado para `update_draft`.

El agente genera operaciones tipadas para agregar, reemplazar o quitar productos; el servidor valida y aplica la actualización de forma atómica. Un ID inexistente, error de modelo o timeout conserva el borrador original. No se envía historial local ni se permite al agente generar precios. Se probaron el SDK y sus salidas con modelo simulado; falta prueba con credenciales reales.

El parser demo reconoce leche, huevos, arroz y parmesano, cantidades numéricas y unidades. Ejemplos: `Agrega 2 litros de leche y 12 huevos`, `Cambia leche a 3 litros`, `Quita huevos`. Pide aclaración si no entiende. No es un sustituto del agente IA de producción.

## Firecrawl real

Configura `FIRECRAWL_API_KEY` y `DATA_MODE=live`. La clave pertenece a la aplicación; el login MCP de Codex no la configura. Los secretos van en `.env`, nunca en Git. El adaptador busca URLs de productos en los dos dominios oficiales y recupera como máximo dos fichas por tienda y producto. Los snippets de búsqueda no se usan como precios.

Los parsers específicos extraen el producto principal y precio explícito. Se conservan fechas de caché y sucursales observadas; se rechazan formatos desconocidos, bloqueos y unidades ambiguas. No se usan proxies stealth ni se resuelven CAPTCHAs. Una fuente fallida produce una respuesta parcial cuando hay otros resultados.

**Cobertura comprobada:** fichas públicas de leche y arroz de ambas tiendas mediante Firecrawl MCP, con pruebas locales sobre las respuestas capturadas. No equivale a cobertura completa ni a una prueba autenticada de la aplicación Node. Ver [evidencia y límites](docs/source-validation.md).

La ubicación aún no configura una sesión/sucursal del supermercado. Las comparaciones live con resultados incluyen `LOCATION_UNVERIFIED` y status `partial`; no se presentan como precios confirmados para el código postal solicitado.

## Comparación

- Convierte g/kg, ml/L y piece/dozen; nunca convierte peso a volumen.
- Compra paquetes completos, redondeando hacia arriba. Calcula importes en centavos.
- Evalúa combinaciones de una o dos tiendas y elige el menor costo entre los candidatos disponibles.
- Cada línea usa una sola presentación/SKU; todavía no mezcla presentaciones dentro de una misma línea ni consolida líneas duplicadas del borrador.
- Prioriza cubrir todos los productos; si no es posible, maximiza los cubiertos y luego minimiza el costo. Los faltantes quedan explícitos, no se presentan como una cesta completa.
- El ahorro usa la cesta completa más barata de una tienda, no la suma de precios regulares; es null si no hay referencia comparable o se usan datos vencidos.
- Todos los matches son `similar` hasta disponer de identidad de SKU fiable. Las notas especiales (por ejemplo, sin lactosa) se marcan para revisión; no se ignoran.
- No incluye transporte, entrega, promociones por volumen ni costos de visitar tiendas.

## Supabase y consumidores

`backend/repository.ts` define `search` y `upsert`. La integración concreta queda pendiente del esquema del responsable de datos. Se inyecta en `buildApp` en `backend/server.ts`. No se han inventado tablas ni creado otra base de datos. Sin adaptador, live consulta Firecrawl en cada comparación y no persiste.

iOS puede trabajar con `fixtures/update-draft.response.json`, `fixtures/compare.response.json`, `fixtures/compare.partial.response.json`, `fixtures/compare.empty.response.json` y `fixtures/compare.error.response.json`. Los contratos están en [contracts/api.md](contracts/api.md) y la frontera para el cliente nativo en [docs/SWIFT_INFRASTRUCTURE.md](docs/SWIFT_INFRASTRUCTURE.md).

## Verificar

```sh
npm run typecheck
npm test
npm run contracts
npm run fixtures
npm run build
npm start
# En otra terminal, con el servidor en modo demo:
npm run smoke
```

Las pruebas no consumen créditos. Los scrapes live y el agente remoto sí pueden consumirlos. Timeout global: 25 segundos; máximo 20 productos y 2 productos en proceso simultáneo. El servidor escucha en loopback por defecto. No está preparado para exposición pública: faltan autenticación y límites de peticiones.

## Pendientes para integración real

1. Configurar las dos claves y elegir `AGENT_MODEL`.
2. Conectar el repositorio Supabase al esquema acordado.
3. Validar ubicación/sucursal, más categorías y restricciones de producto.
4. Revisar con el equipo los detalles de contrato todavía no definidos en el acuerdo.
5. Conectar iOS y ejecutar el caso de aceptación desde el simulador.

Todo el código permanece local; el repositorio remoto conserva únicamente el acuerdo compartido.

### Presentación local del MVP

Abre http://127.0.0.1:3000/ con `npm start`. La interfaz incluye chat,
edición de cantidades, comparación entre Chedraui y Bodega Aurrera e historial
local en el navegador. Usa la lista de ejemplo (2 L de leche, 12 huevos y 1 kg
de arroz), pulsa **Comparar precios** y muestra el resultado de $134 MXN y
$6 MXN de ahorro con los fixtures de demo. Son precios ficticios.

Para interpretar mensajes con Claude directamente, configura `ANTHROPIC_API_KEY`
y `CLAUDE_MODEL` en `.env` (solo servidor, nunca en el navegador). Sin proveedor
configurado, el modo demo utiliza el intérprete limitado de demostración.
El historial guarda comparaciones, no compras efectuadas. El modo de presentación
no consulta precios en vivo con Firecrawl.

### Integración funcional (27 octubre 2026)

- Supabase local: migraciones, seed y RPC en `database/`; adaptador en `backend/supabase-repository.ts`.
- `npm run smoke:db`: flujo completo con la base real (sin catálogo en memoria).
- `npm run smoke:scrapers`: dos consultas con la clave REST de Firecrawl.
- Se retiró el caso de queso escrito directamente en el frontend.
- Resultados web muestran fuentes, fechas, precio unitario, estado y elementos sin coincidencia.
- La app iOS del equipo usa `GroceryAPIClient` y compila en GitHub Actions; aún requiere prueba del flujo en simulador y dispositivo.
- Guía canónica actual: `docs/setup.md`; estado de entrega: `docs/integration-checklist.md`.
