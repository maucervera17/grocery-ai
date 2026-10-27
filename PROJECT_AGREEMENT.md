# Grocery AI — Acuerdo maestro de desarrollo e integración

**Proyecto:** Grocery AI (nombre provisional)  
**Plataforma:** iOS  
**Equipo:** 4 personas  
**Contexto:** Hackathon  
**Principio central:** Cuatro personas desarrollan módulos compatibles en paralelo; **una persona asignada integra el producto completo al final**. Nadie crea una segunda versión de un módulo ajeno.

---

## 1. Qué vamos a construir

Una app iOS conversacional que ayuda a encontrar productos y descuentos de supermercados. Ejemplo: el usuario pregunta «¿Dónde me conviene comprar parmesano?» y recibe opciones comparables con tienda, presentación, precio, precio por unidad, fecha de verificación y enlace de origen.

### Flujo principal obligatorio (MVP)

1. El usuario escribe una pregunta en el chat iOS.
2. La app llama a **un solo endpoint del backend**.
3. El backend interpreta el producto y consulta los precios almacenados.
4. Si los datos faltan o están vencidos, el backend solicita actualización al módulo de obtención de datos, sujeto a disponibilidad de las fuentes.
5. El backend normaliza/compara resultados y responde en un **formato JSON acordado**.
6. iOS muestra texto, tarjetas de precios, fuente y fecha de revisión.
7. El usuario puede guardar un producto en una lista simple.

### Fuera de alcance del MVP

- Compra o pago directamente dentro de la app.
- Automatización de compras, inventario en tiempo real o garantías de precio.
- Cobertura de todos los supermercados o todas las ciudades.
- Sistemas separados de autenticación, múltiples bases de datos, múltiples servicios de IA o microservicios innecesarios.
- Redes sociales, recetas avanzadas, suscripciones y notificaciones push.

**Criterio de éxito:** una búsqueda real o demostrable de principio a fin en un dispositivo/simulador, con al menos dos tiendas y datos trazables. Si falla el scraping en vivo, se muestran datos de ejemplo explícitamente señalados como tales; nunca se presentan datos ficticios como precios actuales.

---

## 2. Decisiones técnicas que NO se discuten por separado

| Capa | Decisión común | Responsable |
|---|---|---|
| iOS | SwiftUI, una sola app/Xcode project | Persona 1 |
| API y agente | TypeScript + Node.js, un solo backend HTTP | Persona 2 |
| Datos | Supabase/PostgreSQL, una sola base de datos | Persona 3 |
| Extracción | Adaptadores de fuentes, jobs invocados por backend | Persona 4 |
| Integración final | Persona 2 (integrador designado) | Persona 2 |
| Contrato API | `contracts/api.md` + esquemas JSON | Persona 2 propone; los 4 aprueban antes de desarrollar |
| Código | Un repositorio Git con carpetas aisladas | Todos |

**Nota:** Firecrawl puede ser una opción para extracción, pero no debe darse por hecho que accede a todos los supermercados. Solo utilizar fuentes permitidas y accesibles; respetar términos de uso, límites y protección de datos.

---

## 3. Distribución exacta del equipo

### Persona 1 — iOS / UI / UX

**Propiedad exclusiva:** `/ios/`

**Construye:**
- Proyecto SwiftUI único.
- Pantalla de chat y estado de carga/error.
- Tarjetas de resultados (tienda, producto, presentación, precio, precio unitario, actualización y URL).
- Vista sencilla de descuentos y lista guardada.
- Cliente HTTP que consume el contrato común de la API.
- Estados vacíos y muestra cuando la información está desactualizada o es demostrativa.

**NO construye:** su propio agente, scraping, base de datos, lógica de ranking en el teléfono, endpoints alternativos.

**Entrega al integrador:** rama lista, pasos de ejecución de Xcode, captura/video corto del flujo y lista de supuestos. Debe poder funcionar con un JSON fixture idéntico al contrato definitivo.

**Definición de terminado:** el flujo visual funciona con mocks contractuales y puede cambiarse a la URL real del backend mediante una sola variable de configuración.

### Persona 2 — Backend / IA / Integrador final

**Propiedad exclusiva:** `/backend/` y `/contracts/`

**Construye:**
- Un API HTTP estable.
- Endpoint `POST /v1/chat/search`.
- Extracción de intención de la pregunta, búsqueda y respuesta conversacional.
- Orquestación: consultar datos, pedir refresh al módulo de extracción cuando se requiera, normalizar y ordenar resultados.
- Validación de entrada/salida, timeouts, manejo de errores y logs.
- Capa de acceso mediante interfaces definidas con Personas 3 y 4.
- Prueba de integración de extremo a extremo.

**Responsabilidad adicional:** es el **único integrador final**. Reserva una fase exclusiva al cierre para unir ramas, configurar variables, probar el flujo total y solucionar incompatibilidades. Puede solicitar correcciones a cada dueño, pero mantiene control de la rama `main` durante integración.

**NO construye:** pantallas iOS, scrapers duplicados ni tablas nuevas fuera del esquema acordado sin consenso.

**Entrega:** backend funcional, especificación de API, instrucciones de despliegue local y lista de variables necesarias.

### Persona 3 — Base de datos / catálogo / normalización

**Propiedad exclusiva:** `/database/`

**Construye:**
- Esquema Supabase/PostgreSQL y migraciones reproducibles.
- Tablas `products`, `retailers`, `stores`, `listings`, `prices`, `price_history` y `saved_items` (simplificar según tiempo).
- Índices, relaciones y reglas para impedir duplicados.
- Seeds con productos de prueba y al menos dos tiendas.
- Funciones/repositorio de acceso a datos acordados con Persona 2.
- Reglas de normalización de tamaño, unidad, moneda, marca, tienda y fecha.

**Reglas de datos:**
- Precio en MXN como entero de centavos (`price_cents`), no como float.
- `quantity` y `unit` separados; distinguir g, kg, ml, L, pieza.
- Una oferta enlaza al producto de origen, a su tienda y URL.
- Guardar `checked_at` y opcionalmente `expires_at` para explicar frescura.
- Productos similares no son automáticamente el mismo SKU; indicar si el match es exacto o sustituto.

**NO construye:** scraper propio, UI o chat.

**Entrega:** SQL/migraciones, seed, diagrama lógico sencillo y README con comandos para iniciar la base.

### Persona 4 — Extracción de precios / fuentes

**Propiedad exclusiva:** `/scrapers/`

**Construye:**
- Adaptadores por tienda/fuente (inicialmente dos, según accesibilidad).
- Entrada normalizada: término de búsqueda, código postal/sucursal opcional y límite de resultados.
- Salida validada según `ScrapedListing` del contrato.
- Extracción de nombre, presentación, precio, promoción, URL, retailer, fecha y sucursal cuando exista.
- Mecanismos de timeout, retry acotado y detección de fallos.
- Fixtures de respuesta y pruebas de dos consultas representativas.

**NO construye:** base de datos propia, UI, agente de IA ni API pública paralela.

**Entrega:** función/servicio invocable por Persona 2, documentación de ejecución, cobertura real por fuente, restricciones y ejemplos JSON.

**Importante:** no evadir controles de acceso ni falsear precios. Si una fuente no es confiable, reportarlo y reemplazarla por otra permitida o por dataset de demo claramente identificado.

---

## 4. Contrato compartido — CONGELAR ANTES DE PROGRAMAR

Todos deben acordar estos campos, nombres, tipos y significado. Persona 2 mantiene el documento canónico `/contracts/api.md` y su JSON Schema (o equivalente), aprobado por los cuatro. Los ejemplos aquí son la versión inicial.

### Request

`POST /v1/chat/search`

```json
{
  "message": "¿Dónde encuentro parmesano más barato?",
  "location": { "postal_code": "06700" },
  "conversation_id": null
}
```

### Response

```json
{
  "conversation_id": "demo-001",
  "reply": "Encontré opciones de parmesano. Compara también el precio por 100 g.",
  "status": "complete",
  "results": [
    {
      "listing_id": "walmart-parmesano-150g",
      "product_name": "Queso parmesano rallado",
      "brand": "Marca ejemplo",
      "retailer": "Tienda A",
      "store_name": null,
      "quantity": 150,
      "unit": "g",
      "price_cents": 8990,
      "regular_price_cents": 9990,
      "currency": "MXN",
      "unit_price_cents_per_100": 5993,
      "product_url": "https://example.com/producto-demo",
      "checked_at": "2026-10-27T20:00:00Z",
      "data_status": "demo",
      "match_type": "similar"
    }
  ],
  "errors": []
}
```

**Los datos anteriores son ficticios y exclusivos para probar la interfaz.** `data_status` admitirá `verified`, `stale` o `demo`. `match_type` será `exact` o `similar`. `status` será `complete`, `partial` o `error`.

### Contrato interno de extracción

```ts
export type ScrapeQuery = {
  query: string;
  postalCode?: string;
  maxResults?: number;
};

export type ScrapedListing = {
  source: string;
  retailer: string;
  storeName?: string;
  productName: string;
  brand?: string;
  quantity?: number;
  unit?: "g" | "kg" | "ml" | "L" | "piece";
  priceCents: number;
  regularPriceCents?: number;
  currency: "MXN";
  productUrl: string;
  checkedAt: string;
};
```

**Importante:** un único adaptador traduce `ScrapedListing` a `listings`/`prices`. El scraper no decide rankings ni escribe tablas de forma independiente. El backend no cambia los formatos por su cuenta.

### Manejo de errores

- Si scraping falla: devolver información vigente en caché o respuesta parcial explicando la limitación.
- Si no hay resultados: devolver `results: []` y mensaje útil.
- Si faltan ubicaciones/sucursales: no afirmar que el precio aplica a una tienda física específica.
- Nunca dejar la app esperando indefinidamente; definir timeout y estado de carga.

---

## 5. Estructura única del repositorio

```text
grocery-ai/
├── README.md
├── PROJECT_AGREEMENT.md
├── .env.example
├── contracts/
│   ├── api.md
│   ├── chat-search.request.schema.json
│   ├── chat-search.response.schema.json
│   └── scraped-listing.schema.json
├── ios/                  # Persona 1
├── backend/              # Persona 2
├── database/             # Persona 3
│   ├── migrations/
│   └── seed/
├── scrapers/             # Persona 4
├── fixtures/             # Ejemplos compartidos, cambios revisados
└── docs/
    ├── setup.md
    ├── decisions.md
    └── integration-checklist.md
```

**Reglas:** un repositorio, una rama `main`, un backend, una base de datos, un contrato API y una app iOS. No crear proyectos separados para después intentar unirlos.

---

## 6. Reglas de colaboración y Git

1. **`main` es siempre integrable.** Nadie hace push directo a `main`, salvo el integrador durante el cierre.
2. Una rama por persona: `feat/ios`, `feat/backend`, `feat/database`, `feat/scrapers`.
3. Cada persona cambia principalmente su carpeta asignada. Los cambios en `contracts/` requieren aprobación de los cuatro y aviso explícito.
4. Todos desarrollan contra los fixtures acordados, aunque otra pieza no esté terminada.
5. Pull requests pequeños con: qué cambió, cómo probarlo y dependencias.
6. No se renombran campos de JSON, tablas, rutas o funciones compartidas sin actualizar contrato, fixtures y consumidores.
7. Secretos únicamente en variables de entorno; jamás subir API keys, service role keys ni credenciales.
8. Si alguien necesita modificar un módulo ajeno, solicita el cambio al dueño. En integración, Persona 2 puede aplicar fixes coordinados.
9. Toda función crítica tiene un ejemplo ejecutable o prueba mínima.
10. Al cerrar cada bloque de trabajo, cada integrante comunica: **terminado / bloqueado / próximo / cambios al contrato**.

### Decisiones de producto

Si hay desacuerdo, se prioriza: (1) flujo completo funcionando, (2) datos fiables, (3) claridad de demo, (4) mejoras visuales, (5) extras. El integrador decide el alcance final para evitar bloqueos.

---

## 7. Plan de ejecución paralelo + integración final

El tiempo se expresa en porcentajes, para adaptarse a un hackathon de cualquier duración.

| Fase | Porcentaje del tiempo | Todos / responsable | Entregable |
|---|---:|---|---|
| A. Alineación | 0–10% | Los 4 | Scope, stack, contrato JSON y ejemplo aprobado |
| B. Desarrollo paralelo | 10–60% | Cada dueño | 4 módulos independientes probables con fixtures |
| C. Integración temprana | 60–75% | Persona 2 + apoyo puntual | Primera búsqueda completa de iOS a datos |
| D. **Integración final exclusiva** | **75–90%** | **Persona 2 lidera** | Main estable, configuración única, fixes de compatibilidad |
| E. Demo y congelamiento | 90–100% | Todos | Prueba final, pitch y video de respaldo |

**Regla de oro:** a partir de la fase D, se detienen features nuevas. Personas 1, 3 y 4 quedan disponibles para corregir exclusivamente los bugs que Persona 2 les asigne. No se refactoriza por estética ni se cambia el contrato.

### Dependencias tempranas

- Persona 1 inicia con fixtures, sin esperar al backend.
- Persona 2 implementa endpoint mock con la respuesta oficial, sin esperar a DB/scrapers.
- Persona 3 define migraciones y seed, sin esperar scraping.
- Persona 4 trabaja con esquema de salida validado, sin esperar DB.
- La unión comienza en fase C, **no** cuando los cuatro terminen por completo.

---

## 8. Checklist de entrega por persona

### Persona 1 — iOS

- [ ] Xcode project abre y compila.
- [ ] Chat permite escribir y enviar consultas.
- [ ] Se renderiza una respuesta con varios resultados.
- [ ] Muestra precio, moneda, tamaño y tienda.
- [ ] Muestra indicador de dato demo, vencido o verificado.
- [ ] La URL del backend se configura en un lugar.
- [ ] Estados de loading, vacío y error probados.
- [ ] README con pasos para ejecutar.

### Persona 2 — Backend e integración

- [ ] Contrato request/response publicado y congelado.
- [ ] `POST /v1/chat/search` responde con fixture inicialmente.
- [ ] Lectura a Supabase conectada.
- [ ] Adaptador de scraping conectado.
- [ ] Normalización/ranking evita comparar presentaciones incorrectamente.
- [ ] Los errores devuelven JSON estable.
- [ ] Variables de entorno documentadas.
- [ ] Smoke test de punta a punta funcionando.
- [ ] Rama `main` lista para la demo.

### Persona 3 — Base de datos

- [ ] Migraciones corren desde cero.
- [ ] Seed poblado con datos de prueba etiquetados.
- [ ] Catálogo relaciona producto, tienda y oferta.
- [ ] Registros de precio incluyen fecha y fuente.
- [ ] No hay duplicados por reimportar el mismo listing.
- [ ] Consultas por producto y tienda funcionan.
- [ ] Acceso con credenciales mínimas y sin secretos expuestos.
- [ ] README con setup y pruebas.

### Persona 4 — Scraping

- [ ] Dos fuentes/adaptadores probados, si son técnicamente accesibles.
- [ ] Cada resultado tiene URL y momento de consulta.
- [ ] Responde JSON con forma `ScrapedListing`.
- [ ] Maneja fallos y timeouts.
- [ ] No confunde tamaños o monedas.
- [ ] Reporta qué sitios/productos no pudo consultar.
- [ ] Fixtures y comando de prueba incluidos.
- [ ] README de dependencias, límites y operación.

---

## 9. Protocolo del integrador (Persona 2)

### Antes de integrar

1. Confirmar que cada persona compartió PR, README, fixture y evidencia de prueba.
2. Verificar que todas las respuestas cumplen el contrato congelado.
3. Preparar `.env` local con claves válidas (nunca commit).
4. Crear un registro corto de errores conocidos y responsables.

### Orden exacto de integración

1. **Database → Backend:** aplicar migraciones, seed y comprobar consulta desde API.
2. **Scraper → Backend:** invocar adaptador, validar output y guardar resultados.
3. **Backend → iOS:** conectar URL real y probar consulta desde simulador.
4. **Flujo completo:** usuario escribe → API → DB/scraper → respuesta → tarjetas en app.
5. **Resiliencia:** prueba sin datos, con scraping fallando, sin red y con respuesta lenta.
6. **Demo:** dejar preparada una consulta conocida y un respaldo en video.

### Regla de resolución de bugs

| Bug | Dueño que lo corrige | Quién valida |
|---|---|---|
| Renderizado, navegación, iOS HTTP client | Persona 1 | Persona 2 |
| Endpoints, IA, orquestación, JSON API | Persona 2 | Persona 1 |
| SQL, migraciones, query y normalización DB | Persona 3 | Persona 2 |
| Extracción, parsers, URLs, timeout de fuente | Persona 4 | Persona 2 |
| Contrato inconsistente entre módulos | Persona 2 coordina a dueños | Los 4 |

**No duplicar soluciones:** si scraping falla, no crear otro scraping improvisado dentro del backend; si una consulta SQL falla, no construir un catálogo paralelo en memoria como solución permanente.

---

## 10. Prueba final obligatoria (Acceptance Test)

**Caso:** «¿Dónde está más barato el parmesano?»

- [ ] La app abre sin errores.
- [ ] Se puede enviar la consulta desde iOS.
- [ ] Backend responde JSON válido y consistente.
- [ ] Se consultan productos de al menos dos tiendas (en vivo o demo claramente marcada).
- [ ] Se muestran precios y cantidades comparables.
- [ ] El producto recomendado es realmente el más conveniente según el criterio indicado.
- [ ] Se ve fuente y fecha de verificación.
- [ ] Se puede abrir un enlace del producto.
- [ ] Un fallo de una fuente no rompe toda la app.
- [ ] Existe un video de respaldo del flujo.

**Definition of Done del proyecto:** el flujo principal funciona en una sola app iOS conectada a un solo backend y una sola base de datos. No basta con cuatro demos separadas.

---

## 11. Riesgos y respuestas acordadas

| Riesgo | Acción del equipo |
|---|---|
| Fuente bloquea scraping | Sustituir por otra fuente permitida o demo etiquetada |
| Precios de sucursales distintas | Solicitar ubicación o marcar la cobertura y evitar conclusión tajante |
| Productos no comparables | Comparar precio por 100 g/ml o misma pieza y advertir diferencias |
| IA inventa precios | Los precios salen **solo** de registros estructurados, no del texto generado |
| Backend se retrasa | Persona 1 sigue con fixture contractual; Persona 2 prioriza API mock |
| Integración se rompe | Congelar features, volver a último commit funcional y corregir por módulo |
| Falta tiempo | Reducir a chat + comparación de un producto en dos tiendas |

---

## 12. Acuerdo final del equipo

Cada integrante acepta que:

1. Trabajará exclusivamente dentro de su área, salvo coordinación explícita.
2. Los contratos compartidos son más importantes que las preferencias individuales de implementación.
3. No creará duplicados de funciones, endpoints, tablas, pantallas o servicios que ya tengan dueño.
4. Entregará código ejecutable, no únicamente capturas o una explicación.
5. Informará bloqueos tan pronto aparezcan.
6. Tendrá su módulo disponible antes de la fase final de integración.
7. Durante la integración final, apoyará al integrador asignado y evitará funcionalidades nuevas.
8. La prioridad del equipo es **una demo unificada y confiable**.

### Asignaciones

| Rol | Integrante | Rama |
|---|---|---|
| iOS / UX | Por asignar | `feat/ios` |
| Backend / IA / **Integrador final** | Por asignar | `feat/backend` |
| Base de datos / Catálogo | Por asignar | `feat/database` |
| Scraping / Fuentes | Por asignar | `feat/scrapers` |

### Primera acción del equipo

**Antes de empezar a programar:** los cuatro deben revisar este documento, asignar nombres, elegir las dos primeras fuentes de supermercado, aprobar el JSON de request/response y hacer commit de este acuerdo en `main`.
