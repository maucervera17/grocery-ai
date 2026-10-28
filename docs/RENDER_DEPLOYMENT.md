# Despliegue de Barasu en Render

`render.yaml` define un **Web Service gratuito** conectado a `maucervera17/grocery-ai`, rama `main`, con Node 22, `npm ci && npm run build`, `npm start` y `/health` como verificación. Render asigna una URL HTTPS `*.onrender.com`. El proceso escucha en `0.0.0.0` y usa el puerto que Render proporciona.

El servicio actual es [barasu-api](https://dashboard.render.com/web/srv-dbh6k7flk1mc73fdlb4g), creado en el proyecto Barasu de Render. Su URL pública es **https://barasu-api.onrender.com**. El despliegue de `main` está activo y `GET /health` respondió `status: ok`, `mode: live`, con agente, Firecrawl y base de datos configurados.

Las variables privadas se introducen en Render; sus valores nunca se guardan en Git. Configura `BARASU_ACCESS_PASSWORD` con una contraseña única de 24 caracteres o más, además de `SUPABASE_SERVICE_ROLE_KEY`, `FIRECRAWL_API_KEY`, `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY` y `ELEVENLABS_AGENT_ID`. `SUPABASE_URL` y `CLAUDE_MODEL` ya están definidos sin secretos en `render.yaml`.

`GET /health` queda abierto para la verificación de Render. El resto del sitio y de la API exige HTTP Basic: usuario `barasu` y la contraseña configurada. La web presenta el cuadro de acceso del navegador. En iOS, el usuario introduce la contraseña en **Agente → Ajustes → Backend**; queda en el llavero del dispositivo y se envía solo por HTTPS al backend para chat y sesión de voz. No se incluyen contraseñas ni claves de proveedor en el binario. La clave `service_role` permanece exclusivamente en el backend. La voz remota entrega el token de ElevenLabs tras autenticar la petición.

Esta contraseña compartida es un control **temporal para una demo privada**, no identidad por usuario. Antes de un lanzamiento público se necesita autenticación individual, límites por cuenta y supervisión de costos. El plan gratuito de Render puede suspenderse por inactividad y tarda en iniciar de nuevo; las consultas live pueden consumir créditos de proveedores.

Prueba tras desplegar:

1. `GET https://<servicio>.onrender.com/health` debe devolver `status: ok`, `mode: live` y adaptadores configurados.
2. `GET /` sin credenciales debe responder 401. Con acceso, debe cargar la web.
3. Desde la web autenticada, consultar un producto y confirmar que la respuesta contiene fuentes o errores explícitos, nunca precios demo.
4. Probar `/v1/voice/status` y una sesión de voz autenticada desde el mismo origen.

No coloques la contraseña, tokens de proveedores ni claves Supabase en este archivo o el repositorio. La contraseña compartida de demo se debe sustituir por autenticación individual antes de distribuir la app.
