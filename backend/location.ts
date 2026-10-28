import { z } from 'zod';
import type { FastifyInstance } from 'fastify';
const Coordinates=z.object({latitude:z.number().finite().min(-90).max(90),longitude:z.number().finite().min(-180).max(180)}).strict();
export function registerLocation(app:FastifyInstance, fetcher:typeof fetch=fetch){
  let lastRequest=0;
  const cache=new Map<string,{at:number;result:Record<string,unknown>}>();
  app.post('/v1/location/resolve',async(req,reply)=>{
    reply.header('Cache-Control','no-store');
    const parsed=Coordinates.safeParse(req.body);
    if(!parsed.success)return reply.code(400).send({message:'Coordenadas inválidas.'});
    const {latitude,longitude}=parsed.data;
    const key=`${latitude.toFixed(4)},${longitude.toFixed(4)}`;
    const cached=cache.get(key);
    if(cached&&Date.now()-cached.at<3600000)return cached.result;
    if(Date.now()-lastRequest<1100)return reply.header('Retry-After','2').code(429).send({message:'Espera dos segundos antes de volver a localizarte.'});
    lastRequest=Date.now();
    try{
      const url=new URL('https://nominatim.openstreetmap.org/reverse');
      url.search=new URLSearchParams({lat:String(latitude),lon:String(longitude),format:'jsonv2',addressdetails:'1','accept-language':'es',zoom:'18'}).toString();
      const response=await fetcher(url,{headers:{'User-Agent':'Barasu/0.1 (https://github.com/maucervera17/grocery-ai)'},signal:AbortSignal.timeout(10000)});
      if(!response.ok)throw Error('provider');
      const body=await response.json() as {address?:Record<string,string>};
      const address=body.address;
      if(address?.country_code!=='mx')return reply.code(422).send({message:'Solo buscamos supermercados en México. Escribe un CP mexicano manualmente.'});
      if(!/^\d{5}$/.test(address.postcode??''))return reply.code(422).send({message:'No pude identificar un CP exacto. Ingresa el código postal de tu zona.'});
      const result={postal_code:address.postcode,area:[address.neighbourhood??address.suburb,address.city??address.town??address.municipality,address.state].filter(Boolean).join(', '),country:'MX',requires_confirmation:true,attribution:'© OpenStreetMap contributors'};
      if(cache.size>=100)cache.delete(cache.keys().next().value!);
      cache.set(key,{at:Date.now(),result});
      return result;
    }catch{return reply.code(502).send({message:'No se pudo resolver tu ubicación. Puedes escribir el código postal manualmente.'});}
  });
}
