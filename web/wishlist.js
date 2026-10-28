export function saveProduct(saved, offer, comparison, now=new Date().toISOString()) {
  const l=offer?.listing;
  if(comparison?.data_mode!=='live'||!l||!Number.isSafeInteger(l.priceCents)||l.priceCents<0||!/^https:\/\//.test(l.productUrl))throw Error('Solo puedes guardar ofertas reales con fuente.');
  const prior=saved.find(p=>p.url===l.productUrl);
  const observation={priceCents:l.priceCents,checkedAt:l.checkedAt,scope:comparison.scope,postal:comparison.requested_postal_code??null};
  const observations=prior?[...prior.observations]:[];
  if(!observations.some(o=>o.checkedAt===observation.checkedAt&&o.scope===observation.scope&&o.postal===observation.postal))observations.push(observation);
  return {...prior,id:prior?.id??crypto.randomUUID(),url:l.productUrl,name:l.productName,retailer:l.retailer,image:l.imageUrl??null,query:comparison.query,savedAt:prior?.savedAt??now,observations:observations.slice(-60)};
}
export function priceChange(product){
 const last=product.observations.at(-1);
 if(!last)return null;
 const comparable=product.observations.filter(o=>o.scope===last.scope&&o.postal===last.postal);
 if(comparable.length<2)return null;
 return last.priceCents-comparable.at(-2).priceCents;
}
