export type Selection = {packages:number;priceCents:number;usualPriceCents:number|null};
export type Cart = {id:string;items:Selection[]};
export type Purchase = {id:string;date:string;items:Selection[];paidCents:number;referenceCents:number|null;differenceCents:number|null};
export function parseMoney(text:string):number|null;
export function quoteCart(items:Selection[]):{total:number;reference:number|null;difference:number|null;covered:number};
export function confirmPurchase(cart:Cart,purchases:Purchase[],paidCents:number,date?:string):Purchase;
