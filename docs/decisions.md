# Decisiones de integración

- Se conserva el contrato externo existente; no se agregan acciones ni se renombran campos.
- Ante el texto ambiguo `results: []` del acuerdo se mantiene la respuesta canónica
  `plan.stores: []`, `plan.unmatched_items` y `errors`; no se crea otro formato.
- Persistencia del catálogo: Supabase/PostgreSQL, seis tablas acordadas. Las RPC
  permanecen internas al adaptador; no se expone un segundo API de la aplicación.
- Datos demo aislados por columna `is_demo` y filtro obligatorio del repositorio.
- No se reemplaza una respuesta parcial por una respuesta exitosa inventada.
- La fuente de verdad del borrador e historial continúa en el cliente.
- Queso Oaxaca usa el mismo catálogo/ranking; la demostración especial de frontend fue retirada.
- Base remota aún sin migrar. Integración publicada en GitHub mediante PR #2, con checks de backend e iOS aprobados.
