import test from 'node:test';
import assert from 'node:assert/strict';
import {saveProduct,priceChange} from '../web/wishlist.js';
const offer=(priceCents=6400,checkedAt='2026-10-27T20:00:00Z')=>({listing:{productUrl:'https://example.com/p',productName:'Queso 400g',retailer:'Store',priceCents,checkedAt}});
const comparison={data_mode:'live',scope:'published',requested_postal_code:'06170',query:'queso'};
test('wishlist deduplicates an offer and snapshots price changes without claiming a purchase',()=>{const first=saveProduct([],offer(),comparison);const duplicate=saveProduct([first],offer(),comparison);assert.equal(duplicate.id,first.id);assert.equal(duplicate.observations.length,1);assert.equal(priceChange(first),null);const next=saveProduct([first],offer(6000,'2026-10-27T21:00:00Z'),comparison);assert.equal(priceChange(next),-400);assert.equal(first.observations[0].priceCents,6400);assert.equal('paidCents' in next,false)});
test('wishlist never compares price changes across postal codes or scopes',()=>{const first=saveProduct([],offer(),comparison);const other=saveProduct([first],offer(6000,'2026-10-27T21:00:00Z'),{...comparison,requested_postal_code:'09410'});assert.equal(priceChange(other),null);assert.throws(()=>saveProduct([],offer(),{...comparison,data_mode:'demo'}));});
