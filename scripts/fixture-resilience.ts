import {readFile,writeFile} from 'node:fs/promises';
import {createSearch} from '../backend/service.js';
import {SearchRequest,SearchResponse,type RawListing} from '../contracts/schema.js';
import {RETAILERS,parseProduct} from '../scrapers/retailers.js';
const fixtures:RawListing[]=JSON.parse(await readFile('fixtures/listings.json','utf8'));
const request=SearchRequest.parse(JSON.parse(await readFile('fixtures/compare.request.json','utf8')));
const timer=setTimeout(()=>{},1000);
try {
 const slow=await createSearch({mode:'demo',fixtures,timeoutMs:5,repository:{search:()=>new Promise(()=>{}),upsert:async()=>{}}})(request);
 await writeFile('fixtures/compare.slow.response.json',JSON.stringify(SearchResponse.parse(slow),null,2)+'\n');
 const captured=await Promise.all(RETAILERS.map(async source=>{
  const page=JSON.parse(await readFile(`fixtures/${source.id}.scrape.json`,'utf8'));
  return {...parseProduct(source,page.metadata.sourceURL,page),checkedAt:'2020-01-01T00:00:00Z'};
 }));
 const stale=await createSearch({mode:'live',fixtures:[],repository:{search:async()=>captured,upsert:async()=>{}},scraper:{scrape:async()=>({listings:[],errors:[{source:'all',code:'SOURCE_TIMEOUT',message:'Simulated timeout for fixture',retryable:true}]})}})({...request,items:request.items.slice(0,1)});
 await writeFile('fixtures/compare.stale.response.json',JSON.stringify(SearchResponse.parse(stale),null,2)+'\n');
 console.log('Generated explicit slow/demo fallback and synthetic stale/timeout contract fixtures.');
}finally{clearTimeout(timer)}
