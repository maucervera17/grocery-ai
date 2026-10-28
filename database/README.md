# Catálogo Supabase

Migraciones canónicas: `migrations/202610280001_catalog.sql` y
`migrations/202610280002_catalog_consistency.sql`. `supabase/migrations`
es un enlace a esta carpeta; no hay una segunda copia del esquema.

Tablas: `retailers → stores → listings → products`; `prices` contiene la última
observación y `price_history` conserva observaciones únicas por oferta/fecha.
Un producto de dos fuentes distintas mantiene identidades separadas: el backend
lo etiqueta como similar, nunca asume equivalencia de SKU.

Los importes son enteros de centavos MXN. La caché separa código postal y origen
demo/live. El código postal delimita la consulta, **no certifica cobertura de sucursal**.
El seed usa `is_demo=true` y enlaces example.com; nunca se devuelve como verificado.

## Arrancar localmente

Requiere Docker y Supabase CLI. Desde la raíz:

```sh
supabase start -x realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor
```

Configura `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` del stack local en `.env`,
solo servidor. Ejecuta `npm run smoke:db`. El smoke importa el seed dos veces,
comprueba que no se duplican ofertas, comprueba aislamiento demo/live y ejecuta
el flujo API → base → plan de dos tiendas, sin fixtures en memoria.

## Proyecto remoto

Primero inspeccionar el esquema del proyecto del equipo para detectar nombres
existentes. Aplicar únicamente las migraciones pendientes; nunca resetear una
base compartida.

El proyecto Baras `vlfqqniorpfveuxhqnpt` tiene ambas migraciones y el seed demo
aplicados desde SQL Editor en una transacción. Se verificaron ocho ofertas y dos
tiendas; `npm run smoke:db` y `npm run smoke` pasaron contra la base remota.
La aplicación mediante SQL Editor no registra versiones en el historial de
migraciones de la CLI: antes de un futuro `db push`, reconciliar ese historial
con el esquema existente. No volver a ejecutar las migraciones iniciales.
La clave de servidor está únicamente en `.env`, excluido de Git.

Las funciones RPC `grocery_search_listings` y `grocery_upsert_listings` son el
contrato con `backend/supabase-repository.ts`. La importación es atómica.
`upsert` no reemplaza un precio más nuevo con uno antiguo. Se usa RLS y se revoca
el acceso a tablas/RPC para anon y authenticated: solo el backend usa service_role.
No se almacenan borradores, mensajes ni historiales personales.
