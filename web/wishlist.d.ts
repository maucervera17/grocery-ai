export interface SavedProduct {id:string;url:string;name:string;retailer:string;image:string|null;query:string;savedAt:string;observations:{priceCents:number;checkedAt:string;scope:string;postal:string|null;location?:{postal_code:string;fulfillment?:string;pickup_store?:string}|null}[]}
export function saveProduct(saved:SavedProduct[], offer:any, comparison:any, now?:string):SavedProduct;
export function priceChange(product:SavedProduct):number|null;
