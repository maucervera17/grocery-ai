import type { FastifyInstance } from 'fastify';

export type VoiceOptions = { apiKey?: string; agentId?: string; fetcher?: typeof fetch; allowedOrigins?: string[]; allowAuthenticatedRemote?: boolean };
// This prototype has no user authentication yet. Do not expose paid voice tokens remotely.
export function registerVoice(app: FastifyInstance, options: VoiceOptions = {}) {
  const configured = Boolean(options.apiKey && options.agentId);
  const attempts = new Map<string, { start: number; count: number }>();
  app.get('/v1/voice/status', async () => ({ configured, provider: 'elevenlabs' }));
  app.post('/v1/voice/session', async (req, reply) => {
    reply.header('Cache-Control', 'no-store');
    const loopback = ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(req.ip);
    const origins = options.allowedOrigins ?? ['http://127.0.0.1:3000', 'http://localhost:3000'];
    const remoteOrigin = req.headers.origin && req.headers.host &&
      req.headers.origin === `https://${req.headers.host}`;
    if ((!loopback && !options.allowAuthenticatedRemote) ||
        (req.headers.origin && !origins.includes(req.headers.origin) &&
          !(options.allowAuthenticatedRemote && remoteOrigin)))
      return reply.code(403).send({ error: 'VOICE_ACCESS_DENIED', message: 'La voz está habilitada solo en el entorno local. El despliegue requiere autenticación de usuarios.' });
    if (!configured) return reply.code(503).send({ error:'VOICE_NOT_CONFIGURED', message:'Falta configurar ElevenLabs en el servidor.' });
    const now = Date.now();
    const counter = attempts.get(req.ip);
    const bucket = counter && now-counter.start < 60000 ? counter : {start:now,count:0};
    attempts.set(req.ip,bucket);
    if (++bucket.count > 5) return reply.header('Retry-After','60').code(429).send({error:'VOICE_RATE_LIMIT',message:'Espera un minuto antes de iniciar otra conversación.'});
    let providerStatus: number | undefined;
    try {
      const response = await (options.fetcher ?? fetch)(`https://api.elevenlabs.io/v1/convai/conversation/token?agent_id=${encodeURIComponent(options.agentId!)}`, {
        headers: {'xi-api-key':options.apiKey!}, signal:AbortSignal.timeout(20000),
      });
      providerStatus = response.status;
      if (!response.ok) throw new Error('provider');
      const body = await response.json() as {token?: unknown};
      if (typeof body.token !== 'string' || !body.token) throw new Error('token');
      return { conversation_token:body.token };
    } catch (error) {
      req.log.warn({ providerStatus, errorType: error instanceof Error ? error.name : 'unknown' }, 'ElevenLabs session failed');
      return reply.code(502).send({ error:'VOICE_PROVIDER_UNAVAILABLE',message:'No se pudo iniciar la voz. Revisa la configuración o inténtalo de nuevo.' });
    }
  });
}
