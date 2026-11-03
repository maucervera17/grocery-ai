# Guía para agentes que integran Barasu

Para incorporarte al proyecto, empieza por [docs/AGENT_ACCESS.md](docs/AGENT_ACCESS.md). Antes de cambiar la conexión de la app, lee [docs/BACKEND_SUPABASE_INTEGRATION.md](docs/BACKEND_SUPABASE_INTEGRATION.md). Ese documento describe el backend, el contrato HTTP, las migraciones y las limitaciones de Supabase/iOS. El contrato ejecutable está en `contracts/schema.ts` y los JSON Schema generados en `contracts/`.

Nunca copies `.env`, `SUPABASE_SERVICE_ROLE_KEY` ni otras credenciales a Git, iOS o `web/`. Los clientes llaman al backend; solo el backend llama a Supabase con `service_role`. No ejecutes `supabase db push` contra el proyecto compartido antes de reconciliar el historial de migraciones aplicado desde SQL Editor. Comprueba cualquier cambio de contrato con `npm run contracts`, `npm run typecheck` y `npm test`.

## iOS

El proyecto se genera con XcodeGen (`ios/project.yml`). Después de agregar o quitar archivos ejecuta `cd ios && xcodegen generate`. Compilar y probar:

```sh
cd ios
xcodebuild -project GroceryAI.xcodeproj -scheme GroceryAI -destination 'platform=iOS Simulator,name=iPhone Duo' build
xcodebuild -project GroceryAI.xcodeproj -scheme GroceryAI -destination 'platform=iOS Simulator,name=iPhone Duo' test
```

En esta máquina, los runtimes instalados (iOS 27.x) solo admiten el simulador «iPhone Duo». La prueba `SmokeTests.retryingAFailedMessageDoesNotDuplicateTheUserMessage` ya fallaba antes del onboarding. El onboarding y el paywall están en [docs/IOS_ONBOARDING_PLAN.md](docs/IOS_ONBOARDING_PLAN.md).
