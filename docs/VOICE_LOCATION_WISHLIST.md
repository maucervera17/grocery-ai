# Barasu: guardados, ubicación y voz

## Flujo actual

Barasu compara ofertas y abre el sitio del comercio; no hace pedidos ni cobra. Una oferta real puede guardarse con su imagen, enlace, fecha, presentación y precio observado. Guardados persiste en el navegador (SwiftData en iOS). Actualizar consulta la misma URL y conserva las observaciones anteriores. Un fallo no sobrescribe el precio. El cambio de precio solo compara observaciones de la misma zona, modalidad y alcance. No equivale a ahorro realizado ni garantiza que esa oferta siga siendo la más barata. No hay sincronización entre dispositivos.

## Ubicación

El botón de ubicación permite CP manual o una lectura GPS solicitada por el usuario. La web envía las coordenadas a `/v1/location/resolve`, que consulta Nominatim/OpenStreetMap. La posición no se persiste: solo el CP confirmado. La caché del geocodificador es temporal en memoria, con un máximo de 100 entradas y una hora. La interfaz muestra precisión aproximada y exige confirmar el CP sugerido. Hay cancelación, timeout y alternativa manual para permiso denegado, posición antigua o dirección sin CP. iOS usa CoreLocation y CLGeocoder.

El CP no demuestra cobertura de un supermercado. La verificación de existencias por sucursal sigue dependiendo de cada tienda; una ficha pública nunca se presenta como stock local confirmado.

## ElevenLabs

1. Guardar `ELEVENLABS_API_KEY` solo en `.env`, con acceso ElevenAgents limitado.
2. Para una cuenta sin agente, ejecutar `npm run voice:setup`. Crea un agente privado desde `config/elevenlabs-agent.json` y guarda su ID localmente. No duplica un agente existente.
3. `npm run build && npm start` carga las variables nuevas.
4. Abrir Modo de voz y pulsar Iniciar conversación. El navegador pide micrófono. Terminar, cambiar de pestaña o salir libera la sesión. Se puede silenciar y volver a iniciar.

El servidor entrega un token temporal WebRTC, nunca la clave. El agente usa `barasu_search` para consultar la API real y `barasu_save` para guardar una oferta de la última búsqueda ante petición explícita. El audio y la transcripción se procesan en ElevenLabs. Los límites del agente son 5 minutos por conversación, 2 conversaciones simultáneas y 20 diarias; el servidor limita inicios a 5/minuto.

El endpoint de voz admite loopback en local. En el despliegue de demo, el backend exige HTTP Basic sobre HTTPS antes de emitir un token; si la solicitud lleva `Origin`, debe coincidir con el origen del servicio. Un cliente iOS debe configurar la URL HTTPS, presentar las credenciales de acceso al usuario y registrar `barasu_search` como herramienta cliente. La clave de ElevenLabs nunca se incluye en la app. Para un lanzamiento público se necesita autenticación individual en vez de la contraseña compartida de demo.

## Evidencia de esta entrega

- Prueba real de ElevenLabs: sesión autenticada con entrada de texto sintética, invocación de `barasu_search`, consulta real de parmesano y respuesta con audio. Ofertas de 85 g a $39 en Walmart y Bodega Aurrera. Son observaciones de esa consulta, no precios permanentes. Ejecutable: `node --env-file-if-exists=.env --import tsx scripts/voice-smoke.ts` (consume créditos).
- GPS real autorizado en Chrome: CP sugerido 06170, precisión aproximada de 35 m, confirmación visible. No se registran aquí coordenadas.
- Wishlist en Chrome: guardar parmesano, recargar, recuperar el registro y actualizar la misma oferta; conserva imagen, enlace y fecha. Capturas locales en `.artifacts/` (no versionadas).
- Pruebas automatizadas cubren permisos, cancelación, respuestas tardías, sesión, herramientas, aislamiento de zonas, errores de proveedor y secretos. `npm test` y `npm run build`.
- Compilación iOS con SDK ElevenLabs validada en CI; no se ha validado una conversación en un iPhone físico.

La prueba adicional autorizada del micrófono de Chrome recibió la consulta hablada de queso Oaxaca, ejecutó la búsqueda y respondió con voz y cuatro ofertas visuales; se cerró la sesión al terminar. La precisión de un CP sugerido depende del sistema de ubicación y del geocodificador: el usuario puede corregirlo.
