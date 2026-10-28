# Súper semanal en Barasu

La web permite convertir una petición de varios productos en un borrador, elegir presentaciones reales en **Mi lista**, aprobar alternativas y optimizar la lista completa. Reutiliza `/v1/chat/search` para interpretar la lista y consultar cada producto; los cálculos de la lista son deterministas en `web/weekly-plan.js`.

Al abrir una lista de varios artículos, la web consulta automáticamente precios publicados de cada producto, dos consultas a la vez. Muestra avance por artículo y permite elegir ofertas que ya llegaron. La consulta de la lista usa precios publicados aunque la búsqueda individual esté en modo de validación por CP: si una tienda no verifica entrega en esa zona, el usuario sigue pudiendo escoger la presentación como referencia, con una advertencia explícita de que debe confirmar existencias y precio final. Una categoría amplia como «carne» pide tipo o corte solo en esa línea; el resto de la lista sigue cargando. Al volver a la conversación se conserva la tarjeta visual del borrador.

Cuando el usuario pide «selecciona las mejores opciones de precio de mi lista» por texto o voz, o pulsa **Que Barasu elija por precio**, la app elige ofertas vigentes con fuente y enlace por sí sola. Para una cantidad definida minimiza el costo necesario, redondeando paquetes; si falta presentación compara el precio por unidad dentro de una misma dimensión. Respeta el límite de una o dos tiendas y las elecciones manuales. Muestra las elecciones como «Barasu eligió», prepara el plan completo cuando hay cobertura y deja visibles los productos sin oferta suficiente. Las búsquedas que siguen en curso pueden completar la selección; no se atribuye calidad al precio ni se inventa ahorro. El agente remoto de ElevenLabs tiene la acción `select_best` en `barasu_search` para este caso.

## Decisiones y referencias

- Una búsqueda amplia de carne, pollo o queso permite precisar corte, tipo y marca antes de consultar. El usuario elige la presentación y cantidad de paquetes.
- Solo participan la oferta elegida y las alternativas expresamente aceptadas. No se asignan estrellas ni se infiere calidad a partir del precio.
- Las cantidades se normalizan por masa, volumen o piezas; nunca se cruzan dimensiones. Si cambia el tamaño de paquete se redondea hacia arriba y se cobra el paquete completo. La venta explícita por kilogramo permite cantidades fraccionarias y precios estimados sujetos al pesaje; el peso aproximado de una charola no se interpreta como base del precio por kilo.
- Las ofertas de más de una hora quedan fuera de nuevas optimizaciones. Cambiar ubicación invalida ofertas y estimaciones de traslado, manteniendo los productos pedidos.
- Se muestran alternativas de menor precio y una tienda. Solo las listas con cobertura completa tienen un ganador y diferencia estimada frente al precio habitual.
- Conveniencia requiere minutos y costo de visita/traslado o envío ingresados por el usuario para cada tienda. Se suma el costo monetario más el valor declarado del tiempo. Para dos tiendas se suman visitas independientes: no es un itinerario optimizado ni una ruta GPS calculada. Un enlace a mapas permite buscar sucursales cerca del CP.
- El precio habitual corresponde a la presentación inicialmente elegida. Aceptar otra marca/presentación es una decisión del usuario y no una afirmación de equivalencia de calidad.

## Histórico

Ahorro muestra por separado listas preparadas (estimado) y compras realizadas (declaradas). El usuario confirma el importe efectivamente pagado por los productos de la lista, sin otros artículos ni envío. El registro conserva una copia de los productos y sus referencias. Sin referencia completa el ahorro es desconocido; los importes negativos se conservan. Se rechaza registrar dos veces la misma semana. «Nueva semana» conserva productos pero crea otra identidad de registro. El almacenamiento es local al navegador.

La página **Tu ahorro** muestra primero la diferencia registrada y el número de compras con referencia completa. Una lista preparada aparece en una sección separada con la etiqueta «Solo estimación». Cada compra muestra lo pagado y la referencia habitual; el detalle explica la resta y permite eliminar o restaurar un registro. Si todavía no hay compras, la página lo dice claramente y ofrece un acceso a Mi lista. La cifra acumulada nunca incluye listas sin compra ni registros con referencias incompletas.

## Salida al comercio

Se prepara una lista por tienda con cantidades, enlaces y descarga de texto. El usuario agrega cada artículo al carrito del comercio. No existe todavía una transferencia automática de carrito, una reserva de inventario o pago dentro de Barasu. No se encontraron contratos públicos verificados para crear carritos completos de las tres tiendas. No se debe etiquetar un enlace de producto como checkout completado.

Fuentes de los flujos propios del comercio:
- https://www.chedraui.com.mx/ayuda-rapida/carrito-de-compras
- https://www.chedraui.com.mx/checkout-io/cart
- https://www.bodegaaurrera.com.mx/imagenes/Informativo/Como_hago%20mi_despensa.pdf

La disponibilidad local sigue dependiendo de evidencia de cada tienda. Un CP resuelto por GPS no prueba existencias. Esta entrega de lista semanal corresponde al prototipo web; la aplicación iOS conserva su integración anterior y requiere portar este nuevo flujo antes de ofrecer paridad.

## Verificar

`npm test` incluye optimización por tiendas, paquetes completos, alternativas rechazadas, unidades incompatibles, cobertura incompleta, datos vencidos, costos desconocidos y registros duplicados. `npm run build` comprueba el backend y el bundle de voz. Prueba de interfaz: pedir huevos, pechuga, carne molida y queso Oaxaca; elegir productos en Mi lista; optimizar; revisar Ahorro sin registrar una compra ficticia.

## Evidencia observada el 27 de octubre de 2026

- Chrome interpretó 12 huevos, 1 kg de pechuga, 500 g de carne molida y 400 g de Oaxaca como cuatro líneas. La lista y selecciones sobrevivieron a recargas.
- Selección de prueba con ofertas reales: San Juan 12 piezas $30, pechuga sin hueso $170/kg (1 kg estimado), Marketside 80/20 500 g $61 y Great Value Oaxaca 400 g $64. Resultado: $325 en Bodega Aurrera entre las alternativas aprobadas. La carne 70/30 más barata no sustituyó la 80/20 elegida. Son precios publicados, no disponibilidad local confirmada.
- El histórico mostró la lista preparada separada de 0 compras realizadas. No se inventaron precios habituales ni se registró una compra durante la prueba.
- ElevenLabs real recibió una petición sintética de cuatro productos, invocó update_draft una vez y respondió con voz remitiendo a Mi lista.
- 90 pruebas automatizadas pasan, junto con compilación TypeScript. Se incluyen precio por kg vs peso de charola, la distinción «sin hueso» frente a «con hueso y sin piel», y recomendaciones automáticas con unidades, vigencia, tienda y selecciones manuales.
- Regresión de nueve artículos con CP 06170: «parmesano, huevo, carne, pollo, cereal, lentejas, arroz, miel, café». Mi lista empezó a consultar automáticamente y terminó con ofertas reales en ocho líneas: parmesano 4, huevo 4, pollo 1, cereal 4, lentejas 2, arroz 4, miel 4 y café de Oaxaca 2. «Carne» pidió tipo o corte en su propia línea, con atajos para precisarlo. Se eligieron parmesano, huevo y cereal durante la búsqueda y se confirmó que la selección sobrevivió a una recarga; después se quitaron esas selecciones de prueba. El CP 06170 no fue confirmado por las tiendas, así que estas ofertas se etiquetan como precios publicados y no como inventario local verificado.

## Verificación del 28 de octubre de 2026

- En Chrome, Barasu eligió automáticamente el huevo San Juan 12 piezas a $30 para una petición de 12 piezas, mientras preservó las otras tres elecciones manuales. La lista completa siguió en $325 y conservó enlaces de producto. Después se restauró la selección manual y su alternativa aceptada.
- La frase «Ayúdame a seleccionar las mejores opciones de precio de mi lista» abrió Mi lista, conservó las cuatro selecciones y mostró el plan. La acción `select_best` se comprobó también en la configuración remota de ElevenLabs.
