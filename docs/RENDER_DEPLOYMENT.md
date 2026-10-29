# Despliegue de Barasu en Render

`render.yaml` define un **Web Service gratuito** conectado a `maucervera17/grocery-ai`, rama `main`, con Node 22, `npm ci && npm run build`, `npm start` y `/health` como verificación. Render asigna una URL HTTPS `*.onrender.com`. El proceso escucha en `0.0.0.0` y usa el puerto que Render proporciona.

El servicio actual es [barasu-api](https://dashboard.render.com/web/srv-dbh6k7flk1mc73fdlb4g), creado en el proyecto Barasu de Render. Su URL pública es **[https://barasu-api.onrender.com](https://barasu-api.onrender.com)** y la [ruta de salud](https://barasu-api.onrender.com/health) es pública. El despliegue de `main` está activo y `GET /health` respondió `status: ok`, `mode: live`, con agente, Firecrawl y base de datos configurados.

Las variables privadas se introducen en Render; sus valores nunca se guardan en Git. Configura `BARASU_ACCESS_PASSWORD` con una contraseña única de 24 caracteres o más, además de `SUPABASE_SERVICE_ROLE_KEY`, `FIRECRAWL_API_KEY`, `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY` y `ELEVENLABS_AGENT_ID`. `SUPABASE_URL` y `CLAUDE_MODEL` ya están definidos sin secretos en `render.yaml`.

`GET /health` queda abierto para la verificación de Render. La interfaz pública vive en **[https://barasu-web.vercel.app](https://barasu-web.vercel.app)**. Vercel sirve los archivos web y reenvía `/v1` a Render. Desde ese origen, la API permite búsqueda, ubicación y voz sin el cuadro de HTTP Basic, con límites globales por minuto y por día. El sitio servido directamente por Render y los clientes nativos siguen exigiendo HTTP Basic: usuario `barasu` y la contraseña configurada. En iOS, el usuario introduce la contraseña en **Agente → Ajustes → Backend**; queda en el llavero del dispositivo y se envía solo por HTTPS al backend para chat y sesión de voz. No se incluyen contraseñas ni claves de proveedor en el binario. La clave `service_role` permanece exclusivamente en el backend.

La excepción pública es para un prototipo y sus cupos se reinician al reiniciar el proceso. La contraseña compartida tampoco identifica a cada usuario. Antes de escalar se necesitan identidad individual, límites persistentes por cuenta y supervisión de costos. El plan gratuito de Render puede suspenderse por inactividad y tarda en iniciar de nuevo; las consultas live pueden consumir créditos de proveedores. El aviso `.env not found` es normal en Render: las claves privadas se cargan desde **Environment**, no desde un archivo del repositorio.

Prueba tras desplegar:

1. `GET https://<servicio>.onrender.com/health` debe devolver `status: ok`, `mode: live` y adaptadores configurados.
2. `GET /` sin credenciales debe responder 401. Con acceso, debe cargar la web.
3. Desde `barasu-web.vercel.app`, consultar un producto sin cuadro de acceso y confirmar que la respuesta contiene fuentes o errores explícitos, nunca precios demo.
4. Probar `/v1/voice/status` y una sesión de voz desde la web pública; comprobar que una llamada directa no autorizada a Render sigue dando 401.

No coloques la contraseña, tokens de proveedores ni claves Supabase en este archivo o el repositorio. La contraseña compartida de demo se debe sustituir por autenticación individual antes de distribuir la app.
