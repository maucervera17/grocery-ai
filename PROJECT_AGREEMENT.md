# Grocery AI — Acuerdo maestro de desarrollo e integración

**Proyecto:** Grocery AI (nombre provisional)  
**Plataforma:** iOS  
**Equipo:** 4 personas  
**Contexto:** Hackathon  
**Principio central:** Cuatro personas desarrollan módulos compatibles en paralelo; **una persona asignada integra el producto completo al final**. Nadie crea una segunda versión de un módulo ajeno.

---

## 1. Qué vamos a construir

Una app iOS conversacional que ayuda a preparar una lista del supermercado y encontrar la combinación de tiendas con el menor costo estimado. El usuario puede escribir varios productos con sus cantidades, revisar un borrador editable y comparar opciones trazables por tienda, presentación, precio, precio por unidad, fecha de verificación y enlace de origen.

### Flujo principal obligatorio (MVP)

1. El usuario escribe uno o varios productos en el chat iOS, incluyendo cantidades cuando las conozca.
2. La app envía el texto y el borrador actual a **un solo endpoint del backend** con la acción `update_draft`.
3. El backend interpreta la entrada y devuelve productos normalizados. **El backend no conserva el borrador; iOS es la fuente de verdad y lo guarda localmente.**
4. El usuario revisa y modifica nombres, cantidades y unidades mediante controles nativos de iOS.
5. Al pulsar «Comparar precios», la app envía el borrador completo y la ubicación al mismo endpoint con la acción `compare`.
6. El backend consulta precios almacenados. Si faltan o están vencidos, solicita actualización al módulo de obtención de datos, sujeto a disponibilidad de las fuentes.
7. El backend normaliza, compara y responde con una combinación por supermercado en un **formato JSON acordado**.
8. iOS muestra el total estimado, productos agrupados por tienda, fuentes, fechas de revisión y elementos sin coincidencia.
9. iOS guarda localmente el resultado completado y permite reutilizar sus productos como un borrador nuevo.

### Fuera de alcance del MVP

- Compra o pago directamente dentro de la app.
- Automatización de compras, inventario en tiempo real, costo de transporte/entrega o garantías de precio.
- Cobertura de todos los supermercados o todas las ciudades.
- Sistemas separados de autenticación, sincronización del historial entre dispositivos, múltiples bases de datos, múltiples servicios de IA o microservicios innecesarios.
- Redes sociales, recetas avanzadas, suscripciones y notificaciones push.

**Criterio de éxito:** una lista de al menos tres productos procesada de principio a fin en un dispositivo/simulador, con una comparación demostrable entre al menos dos tiendas y datos trazables. Si falla el scraping en vivo, se muestran datos de ejemplo explícitamente señalados como tales; nunca se presentan datos ficticios como precios actuales.

---

## 2. Decisiones técnicas que NO se discuten por separado

| Capa | Decisión común | Responsable |
|---|---|---|
| iOS | Swift 6.2, SwiftUI, mínimo iOS 26, APIs nativas y un solo Xcode project | Persona 1 |
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
- Sistema de diseño con colores semánticos intercambiables; inicialmente usa verde como color principal.
- Pantalla de chat, borrador editable y estados de carga/error.
- Campo conversacional para agregar productos; las compras anteriores se seleccionan desde UI local, no mediante comandos al agente.
- Menú «+» con productos frecuentes, compras anteriores y entrada de lista; no incluye escáner de códigos.
- Tarjetas de resultados agrupadas por tienda (producto, presentación, precio, precio unitario, actualización y URL).
- Historial local de comparaciones y productos frecuentes mediante SwiftData.
- Ubicación con permiso `When In Use`, conversión a código postal y entrada manual como alternativa.
- Cliente HTTP que consume el contrato común de la API.
- Estados vacíos y muestra cuando la información está desactualizada o es demostrativa.

**NO construye:** su propio agente o parser de lenguaje, scraping, base de datos remota, lógica de ranking en el teléfono ni endpoints alternativos. iOS envía el borrador únicamente para `update_draft` o `compare`; nunca envía automáticamente el historial completo.

**Entrega al integrador:** rama lista, pasos de ejecución de Xcode, captura/video corto del flujo y lista de supuestos. Debe poder funcionar con un JSON fixture idéntico al contrato definitivo.

**Definición de terminado:** el usuario puede crear un borrador, editar cantidades, comparar con mocks contractuales, revisar una combinación por tiendas, guardar el resultado localmente y reutilizarlo. La URL real del backend se cambia mediante una sola variable de configuración.

### Persona 2 — Backend / IA / Integrador final

**Propiedad exclusiva:** `/backend/` y `/contracts/`

**Construye:**
- Un API HTTP estable.
- Endpoint `POST /v1/chat/search` con acciones `update_draft` y `compare`.
- Extracción de productos y cantidades, búsqueda y respuesta conversacional.
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
- Tablas `products`, `retailers`, `stores`, `listings`, `prices` y `price_history` (simplificar según tiempo). El borrador, historial personal y productos frecuentes permanecen localmente en iOS durante el MVP.
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

### Endpoint único

`POST /v1/chat/search`

El endpoint es **sin estado respecto al borrador**. iOS envía el borrador actual cuando sea necesario y reemplaza su copia local únicamente después de recibir una respuesta válida.

### Request: actualizar borrador

```json
{
  "action": "update_draft",
  "message": "Agrega 2 litros de leche y 12 huevos",
  "items": [
    {
      "client_item_id": "item-arroz",
      "name": "Arroz",
      "quantity": 1,
      "unit": "kg",
      "notes": null
    }
  ],
  "location": null
}
```

### Response: borrador normalizado

```json
{
  "reply": "Agregué leche y huevos a tu lista.",
  "status": "complete",
  "draft_items": [
    {
      "client_item_id": "item-arroz",
      "name": "Arroz",
      "quantity": 1,
      "unit": "kg",
      "notes": null
    },
    {
      "client_item_id": "item-leche",
      "name": "Leche",
      "quantity": 2,
      "unit": "L",
      "notes": null
    },
    {
      "client_item_id": "item-huevos",
      "name": "Huevos",
      "quantity": 12,
      "unit": "piece",
      "notes": null
    }
  ],
  "plan": null,
  "errors": []
}
```

### Request: comparar borrador

```json
{
  "action": "compare",
  "message": null,
  "items": [
    {
      "client_item_id": "item-leche",
      "name": "Leche",
      "quantity": 2,
      "unit": "L",
      "notes": null
    },
    {
      "client_item_id": "item-huevos",
      "name": "Huevos",
      "quantity": 12,
      "unit": "piece",
      "notes": null
    }
  ],
  "location": { "postal_code": "06700" },
  "preferences": { "max_stores": 2 }
}
```

### Response: combinación por tiendas

```json
{
  "reply": "Encontré una combinación en dos tiendas.",
  "status": "complete",
  "draft_items": [
    {
      "client_item_id": "item-leche",
      "name": "Leche",
      "quantity": 2,
      "unit": "L",
      "notes": null
    },
    {
      "client_item_id": "item-huevos",
      "name": "Huevos",
      "quantity": 12,
      "unit": "piece",
      "notes": null
    }
  ],
  "plan": {
    "total_price_cents": 15180,
    "estimated_savings_cents": 2120,
    "currency": "MXN",
    "stores": [
      {
        "retailer": "Tienda A",
        "store_name": null,
        "subtotal_cents": 7990,
        "items": [
          {
            "client_item_id": "item-leche",
            "listing_id": "tienda-a-leche-1l",
            "product_name": "Leche entera 1 L",
            "brand": "Marca ejemplo",
            "requested_quantity": 2,
            "requested_unit": "L",
            "package_quantity": 1,
            "package_unit": "L",
            "package_count": 2,
            "price_cents": 3995,
            "regular_price_cents": 4495,
            "line_total_cents": 7990,
            "unit_price_cents_per_100": 399,
            "product_url": "https://example.com/leche-demo",
            "checked_at": "2026-10-27T20:00:00Z",
            "data_status": "demo",
            "match_type": "exact"
          }
        ]
      },
      {
        "retailer": "Tienda B",
        "store_name": null,
        "subtotal_cents": 7190,
        "items": [
          {
            "client_item_id": "item-huevos",
            "listing_id": "tienda-b-huevos-12",
            "product_name": "Huevo blanco 12 piezas",
            "brand": "Marca ejemplo",
            "requested_quantity": 12,
            "requested_unit": "piece",
            "package_quantity": 12,
            "package_unit": "piece",
            "package_count": 1,
            "price_cents": 7190,
            "regular_price_cents": 8320,
            "line_total_cents": 7190,
            "unit_price_cents_per_100": null,
            "product_url": "https://example.com/huevos-demo",
            "checked_at": "2026-10-27T20:00:00Z",
            "data_status": "demo",
            "match_type": "similar"
          }
        ]
      }
    ],
    "unmatched_items": []
  },
  "errors": []
}
```

**Los datos anteriores son ficticios y exclusivos para probar la interfaz.** `data_status` admitirá `verified`, `stale` o `demo`. `match_type` será `exact` o `similar`. `status` será `complete`, `partial` o `error`. Las unidades admitidas inicialmente serán `g`, `kg`, `ml`, `L`, `piece`, `package` y `dozen`. Los importes monetarios se expresan como enteros de centavos. `price_cents` es el precio de un paquete y `line_total_cents` es `price_cents × package_count`. `estimated_savings_cents` compara el plan recomendado con la alternativa completa más barata en una sola tienda; será `null` si no existe una referencia comparable. El ranking minimiza el costo de los productos sin superar `preferences.max_stores`, cuyo valor inicial para el MVP es `2`. El total no incluye transporte ni entrega y la interfaz debe indicarlo.

Los elementos de `errors` tendrán forma estable:

```json
{
  "code": "SOURCE_TIMEOUT",
  "message": "Una fuente no respondió a tiempo.",
  "client_item_id": "item-leche",
  "retryable": true
}
```

### Estado y persistencia en iOS

- iOS mantiene un solo borrador activo y lo guarda después de cada modificación.
- El agente recibe el borrador actual, pero no lo conserva como fuente de verdad.
- La respuesta de `update_draft` no se agrega al historial. Solo actualiza el borrador local después de validarse.
- Una comparación completada se guarda localmente como una orden inmutable con una copia de los productos solicitados, asignaciones por tienda, precios y fechas.
- Repetir una orden crea un borrador nuevo usando los productos y cantidades originalmente solicitados; nunca modifica la orden anterior.
- Los productos frecuentes se calculan localmente después de comparaciones completadas.
- El historial local no se envía al agente. El usuario lo incorpora mediante la interfaz si decide reutilizarlo.

### Pantallas obligatorias de iOS

1. Agente y borrador actual.
2. Menú «+» con productos frecuentes, compras anteriores y entrada de lista.
3. Editor de borrador con nombre, cantidad, unidad y detalles opcionales por producto.
4. Ubicación y código postal manual.
5. Estado de comparación.
6. Resultado agrupado por supermercados.
7. Historial local de órdenes y productos.

### Reglas de interacción de iOS

- El campo de texto agrega o modifica productos. Los comandos sobre compras anteriores no se envían al agente.
- Si el usuario no especifica cantidad, el backend devuelve `1` con unidad `piece`, salvo que pueda inferir otra unidad sin ambigüedad. La cantidad siempre permanece editable.
- El usuario confirma el borrador antes de comparar.
- Seleccionar una compra anterior crea una copia editable con las cantidades guardadas.
- El sistema de diseño usa tokens semánticos de color, tipografía, espaciado y radios. Las vistas de funcionalidad no contienen colores de marca directos.
- Todos los controles usan SwiftUI nativo, Dynamic Type y etiquetas accesibles.

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
- [ ] Deployment target configurado en iOS 26 y código compilando con Swift 6.2.
- [ ] Sistema de diseño semántico aplicado; el color principal puede cambiarse sin editar las vistas de funcionalidad.
- [ ] Chat permite agregar uno o varios productos al borrador.
- [ ] El borrador se conserva localmente y permite editar cantidad y unidad.
- [ ] El menú «+» permite seleccionar productos frecuentes, compras anteriores o pegar una lista.
- [ ] Seleccionar una orden anterior crea un borrador nuevo y no modifica el historial.
- [ ] Se renderiza una combinación con productos agrupados por supermercado.
- [ ] Muestra precio, moneda, tamaño y tienda.
- [ ] Muestra indicador de dato demo, vencido o verificado.
- [ ] Muestra productos sin coincidencia y sustitutos de forma explícita.
- [ ] Solicita ubicación únicamente cuando se necesita y permite código postal manual.
- [ ] La URL del backend se configura en un lugar.
- [ ] Estados de loading, vacío y error probados.
- [ ] Fixtures cubren `update_draft`, comparación completa, parcial, vacía, lenta, demo y error.
- [ ] VoiceOver, Dynamic Type, modo claro y modo oscuro revisados.
- [ ] README con pasos para ejecutar.

### Persona 2 — Backend e integración

- [ ] Contrato request/response publicado y congelado.
- [ ] `POST /v1/chat/search` soporta `update_draft` y `compare` con fixtures inicialmente.
- [ ] `update_draft` conserva IDs existentes y devuelve cantidades/unidades normalizadas.
- [ ] Lectura a Supabase conectada.
- [ ] Adaptador de scraping conectado.
- [ ] Normalización/ranking evita comparar presentaciones incorrectamente y respeta `max_stores`.
- [ ] El plan distingue precio por paquete, número de paquetes y total por línea.
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

**Caso:** «Agrega 2 litros de leche, 12 huevos y 1 kg de arroz» y después «Comparar precios».

- [ ] La app abre sin errores.
- [ ] Se pueden agregar los tres productos desde iOS.
- [ ] La app conserva el borrador y permite editar sus cantidades.
- [ ] Backend responde JSON válido y consistente.
- [ ] Se consultan productos de al menos dos tiendas (en vivo o demo claramente marcada).
- [ ] Se muestran precios, presentaciones y cantidades comparables por producto.
- [ ] La combinación recomendada corresponde al menor costo estimado según el criterio indicado.
- [ ] Se ve fuente y fecha de verificación.
- [ ] Se pueden abrir los enlaces de los productos.
- [ ] Se identifican productos sin coincidencia y sustitutos.
- [ ] Un fallo de una fuente no rompe toda la app.
- [ ] El resultado se guarda localmente y puede reutilizarse como un borrador nuevo.
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
