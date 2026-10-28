export function parseMoney(text) {
  const value=String(text).trim().replace(',','.');
  if(!/^\d{1,7}(\.\d{1,2})?$/.test(value))return null;
  const [whole,fraction='']=value.split('.');
  const cents=Number(whole)*100+Number(fraction.padEnd(2,'0'));
  return Number.isSafeInteger(cents)&&cents<=100000000?cents:null;
}
export function quoteCart(items) {
  let total=0,reference=0,covered=0;
  for(const item of items){
    if(!Number.isInteger(item.packages)||item.packages<1||item.packages>99||!Number.isSafeInteger(item.priceCents)||item.priceCents<0||item.priceCents>100000000)throw Error('Selección inválida');
    total+=item.packages*item.priceCents;
    if(item.usualPriceCents!==null&&item.usualPriceCents!==undefined){
      if(!Number.isSafeInteger(item.usualPriceCents)||item.usualPriceCents<0||item.usualPriceCents>100000000)throw Error('Precio habitual inválido');
      reference+=item.packages*item.usualPriceCents;covered++;
    }
  }
  const complete=items.length>0&&covered===items.length;
  return {total,reference:complete?reference:null,difference:complete?reference-total:null,covered};
}
export function confirmPurchase(cart, purchases, paidCents, date=new Date().toISOString()) {
  if(!cart.items.length)throw Error('Tu cesta está vacía');
  if(purchases.some(p=>p.id===cart.id))throw Error('Esta compra ya está registrada');
  if(!Number.isSafeInteger(paidCents)||paidCents<0||paidCents>100000000)throw Error('Importe pagado inválido');
  const q=quoteCart(cart.items);
  return {id:cart.id,date,items:structuredClone(cart.items),paidCents,referenceCents:q.reference,differenceCents:q.reference===null?null:q.reference-paidCents};
}
