import test from 'node:test';import assert from 'node:assert/strict';
import {parseMoney,quoteCart,confirmPurchase} from '../web/savings.js';
test('savings uses a declared same-presentation baseline and integer quantities',()=>{
 assert.deepEqual(quoteCart([{packages:2,priceCents:6400,usualPriceCents:7900}]),{total:12800,reference:15800,difference:3000,covered:1});
 assert.equal(parseMoney('79,50'),7950);assert.equal(parseMoney(''),null);assert.equal(parseMoney('1.001'),null);
});
test('missing references never become zero cost or fictional savings',()=>{
 assert.equal(quoteCart([{packages:1,priceCents:6400,usualPriceCents:null}]).difference,null);
 assert.equal(quoteCart([{packages:1,priceCents:6400,usualPriceCents:7900},{packages:1,priceCents:1000,usualPriceCents:null}]).reference,null);
});
test('confirmed purchases use actual payment, retain losses and reject duplicate recording',()=>{
 const cart={id:'purchase-1',items:[{packages:2,priceCents:6400,usualPriceCents:7900}]};
 const p=confirmPurchase(cart,[],16000);assert.equal(p.differenceCents,-200);assert.equal(p.paidCents,16000);
 assert.throws(()=>confirmPurchase(cart,[p],16000),/registrada/);assert.throws(()=>confirmPurchase({...cart,items:[]},[],0),/vacía/);
 cart.items[0].usualPriceCents=1;assert.equal(p.referenceCents,15800);
});
test('invalid financial values and fractional packages are rejected',()=>{
 for(const packages of [0,-1,1.5,100])assert.throws(()=>quoteCart([{packages,priceCents:6400,usualPriceCents:7900}]));
 assert.throws(()=>confirmPurchase({id:'x',items:[{packages:1,priceCents:10,usualPriceCents:12}]},[],NaN));
});
