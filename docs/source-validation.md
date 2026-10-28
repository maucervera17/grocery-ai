# Validación de fuentes — 27 de octubre de 2026, México

Se usó la conexión MCP de Firecrawl con proxy basic. Esta prueba valida que se obtuvieron páginas y que los parsers locales procesan las capturas; no comprueba la clave REST del backend ni cobertura por código postal.

| Fuente | Consulta | Evidencia | Observación |
|---|---|---|---|
| Chedraui | Leche | https://www.chedraui.com.mx/leche-santa-clara-entera-1l-3019421/p | Ficha primaria, precio individual y promoción por volumen separados; sin ubicación seleccionada. |
| Bodega Aurrera | Leche | https://www.bodegaaurrera.com.mx/ip/leche-santa-clara-entera-1-l/00750129560012 | Respuesta cacheada del 26 de octubre; variante 1 L y sucursal BA CANTIL. No se trata como precio fresco. |
| Chedraui | Arroz | https://www.chedraui.com.mx/arroz-blanco-morelos-organico-1kg-3005713/p | Solicitud maxAge=0; título, cantidad y precio con metadatos MXN. |
| Bodega Aurrera | Arroz | https://www.bodegaaurrera.com.mx/ip/arroz-verde-valle-super-extra-1-kg/00750107130145 | Solicitud maxAge=0; ficha primaria y sucursal BA CANTIL. |

Las capturas en `fixtures/*.scrape.json` conservan metadatos y el fragmento relevante. No se cargan al servicio como ofertas actuales. Los fixtures de la cesta son ficticios y usan example.com.

Pendiente: localidad del usuario, validación de sucursales equivalentes, huevo y más presentaciones, notas alimentarias, revisión de condiciones de las fuentes y una prueba de principio a fin con credenciales de aplicación. Los buscadores pueden mostrar productos irrelevantes: se filtran dominio, ruta y nombre, pero hace falta ampliar la clasificación de catálogo antes de uso general.

## Integración REST y Walmart

El 27 de octubre se configuró la clave REST en el servidor local y se probó
`search → scrape → parse → Supabase → POST /v1/chat/search`. La consulta
«leche entera» obtuvo ofertas de las tres tiendas y la lectura posterior
confirmó su persistencia. Para 1 L, la API seleccionó Walmart por 2000 centavos
entre las ofertas recuperadas. Es una observación de esa ejecución, no un precio garantizado.

`fixtures/walmart.scrape.json` conserva la captura real de
https://www.walmart.com.mx/ip/leche-great-value-entera-1-l/00750649501422
con precio primario de $20.00 y sucursal observada SC TOREO. El parser excluye
artículos similares y conserva el tamaño del producto seleccionado.
La respuesta sigue siendo parcial por ubicación no verificada. Algunas fichas
de la búsqueda fallaron; sus errores no borran las ofertas válidas. La prueba
general de leche/arroz no garantiza cobertura completa de todas las tiendas.
