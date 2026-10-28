# Estado de integración — 27 de octubre de 2026

El acuerdo sigue siendo la referencia de alcance. Esta lista distingue implementación
probada de dependencias externas; no declara terminado el proyecto iOS.

## Probado

- [x] Un endpoint con update_draft / compare, sin persistir borrador en backend.
- [x] Agente Claude conectado; conserva IDs de elementos editados.
- [x] Validación request/response, errores estables, deadline global y logs sin texto personal.
- [x] Ranking por costo de paquetes completos, unidades compatibles, máximo 1 o 2 tiendas.
- [x] Caché, refresh, errores de lectura/escritura/fuentes, frescura y respuesta parcial.
- [x] Supabase local real: migración desde cero y seed de dos tiendas, ocho ofertas.
- [x] Reimportación idempotente, historial de precios, aislamiento postal y demo/live.
- [x] Roles públicos sin acceso al catálogo ni RPC; credenciales solo en backend.
- [x] Datos antiguos no reemplazan precios o metadatos nuevos.
- [x] `npm test`: 31 pruebas. `npm run build`: correcto.
- [x] `npm run smoke:db`: API → Supabase → dos tiendas, total 13400 centavos.
- [x] `npm run smoke`: Claude real → borrador → Supabase local → total 13400, ahorro 600.
- [x] Web muestra fuente, fecha, precio por paquete y por unidad, demo/vencido y similares.
- [x] Web permite notas editables, historial y productos frecuentes calculados localmente.
- [x] Se retiró la respuesta falsa de queso implementada en frontend: ahora usa el catálogo.
- [x] Dos adaptadores Firecrawl con fixtures de leche y arroz; fallos, retry y parsers probados.

## Implementado, con verificación externa pendiente

- [ ] Aplicar migración a Supabase remoto de la cuenta indicada. Organización Baras creada;
  proyecto pendiente del paso de contraseña que debe completar el usuario.
- [ ] Prueba de Firecrawl REST desde backend con credenciales de aplicación.
  El login MCP no equivale a esta conexión. Pestaña de login preparada.
- [ ] Cliente HTTP iOS conectado en la copia local de feat/ios. Sintaxis y proyecto plist
  revisados; no compilado. Xcode/SDK iOS no está instalado en este Mac.
- [ ] Flujo obligatorio en dispositivo/simulador, VoiceOver, Dynamic Type y temas.
- [ ] Ubicación real When In Use en iOS: adaptador añadido con timeout y alternativa manual; pendiente prueba con SDK/dispositivo.
- [x] Fixtures contractuales de respuesta lenta y datos vencidos.
- [ ] Pruebas nativas del cliente HTTP en Xcode.
- [ ] Video de respaldo real del flujo.
- [ ] Publicación e integración de ramas en GitHub: cambios permanecen locales.

## Evidencia

`tests/search.test.ts`, `tests/repository.test.ts`, `database/tests/catalog.sql`,
`scripts/database-smoke.ts`, `scripts/smoke.ts`, `docs/source-validation.md`.

No se garantiza stock ni precio por sucursal. En live, un código postal consultado
no autoriza a presentar una sucursal como verificada. En demo, todos los precios
siguen etiquetados como demo incluso al provenir de la base real.
