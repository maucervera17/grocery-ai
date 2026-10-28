# Ejecución e integración local

1. Node.js 22 o posterior: `npm ci`.
2. `.env` (ignorado por Git): `HOST=127.0.0.1`, `PORT=3000`, `DATA_MODE=demo`.
3. Claude: `ANTHROPIC_API_KEY` y `CLAUDE_MODEL`. Alternativamente, AI Gateway con
   `AI_GATEWAY_API_KEY` + `AGENT_MODEL`. Solo se selecciona un proveedor.
4. Supabase: `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`; migración y seed en
   `database/`. `npm run smoke:db` verifica persistencia real.
5. Firecrawl: `FIRECRAWL_API_KEY` es una clave REST de aplicación. La conexión MCP
   de Codex no configura esa variable. Usa `DATA_MODE=live` para consultar fuentes.
6. `npm run build && npm start`; abre http://127.0.0.1:3000/.
7. `npm test`, `npm run typecheck`, `npm run smoke`.

No colocar claves en web/ ni iOS/. `/health` solo muestra modo y si hay
adaptadores configurados; no es una comprobación de conectividad externa.

## Comportamiento

- Un único POST `/v1/chat/search`, acciones update_draft y compare.
- No hay sesión ni estado de borrador en el backend.
- El modo demo consulta Supabase si se configuró; ante error usa el seed de
  respaldo y devuelve una advertencia, sin cambiar su etiqueta demo.
- El modo live no usa el seed de demo. Caché por producto/código postal, TTL 1 hora.
  Si falta cobertura en alguna de las dos fuentes, pide refresh.
- Dos productos se consultan concurrentemente, máximo cuatro llamadas de fuente
  simultáneas por petición. Deadline total 25 s. Falla de una fuente => parcial.
- Cada producto se compara por el costo de paquetes completos necesarios. Hasta
  dos tiendas; una combinación parcial prioriza cubrir más productos.
- Detalles alimentarios no verificables quedan sin asignar, con explicación.
- No hay precio especial de queso en el navegador. Queso Oaxaca de demo está en
  el catálogo estructurado y pasa por el mismo ranking que cualquier producto.
- Fechas de caché originales se conservan. Fuente, fecha, estado y sustitución
  se devuelven por línea. El código postal no asegura una sucursal física.

## iOS

Se incorporó la rama `feat/ios` del equipo (commit 9243aa01a80a80542c2bfa7f9cb3bbe6bc8479ba)
para integración local. `GroceryAPIClient` implementa los dos servicios existentes,
sin crear otra app. Configuración única: `APIConfiguration.baseURL`.
El simulador puede usar 127.0.0.1; para dispositivo físico se requiere un servidor
accesible por red y la configuración de red local de iOS correspondiente.
El proyecto requiere Xcode con SDK iOS 26. En este Mac no está instalado Xcode;
la compilación se validó en GitHub Actions (run 40621570223), pero el flujo en simulador sigue pendiente.
