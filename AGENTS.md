# Guía para agentes que integran Barasu

Antes de cambiar la conexión de la app, lee [docs/BACKEND_SUPABASE_INTEGRATION.md](docs/BACKEND_SUPABASE_INTEGRATION.md). Ese documento describe el estado actual del backend, el contrato HTTP, las migraciones y las limitaciones de Supabase/iOS. El contrato ejecutable está en `contracts/schema.ts` y los JSON Schema generados en `contracts/`.

Nunca copies `.env`, `SUPABASE_SERVICE_ROLE_KEY` ni otras credenciales a Git, iOS o `web/`. Los clientes llaman al backend; solo el backend llama a Supabase con `service_role`. No ejecutes `supabase db push` contra el proyecto compartido antes de reconciliar el historial de migraciones aplicado desde SQL Editor. Comprueba cualquier cambio de contrato con `npm run contracts`, `npm run typecheck` y `npm test`.
