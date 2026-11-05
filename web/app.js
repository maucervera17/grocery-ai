import {recordWeeklyPurchase} from '/weekly-plan.js';
import {mountWeekly} from '/weekly.js';
import {attachLocation} from '/location.js';
import {saveProduct,priceChange} from '/wishlist.js';
import {mountVoice} from '/voice.js';
import {parseMoney} from '/savings.js';
import {savingsMarkup} from '/savings-view.js';
const $=id=>document.getElementById(id),esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const money=n=>new Intl.NumberFormat('es-MX',{style:'currency',currency:'MXN'}).format(n/100);
const emoji=n=>/desodorante|antitranspirante/i.test(n)?'🧴':/detergente/i.test(n)?'🧼':/pasta|espagueti/i.test(n)?'🍝':/leche/i.test(n)?'🥛':/huevo/i.test(n)?'🥚':/arroz/i.test(n)?'🍚':/queso|parmesano/i.test(n)?'🧀':/pollo/i.test(n)?'🍗':/carne/i.test(n)?'🥩':/cereal/i.test(n)?'🥣':/lenteja/i.test(n)?'🫘':/miel/i.test(n)?'🍯':/caf[eé]/i.test(n)?'☕':/manzana/i.test(n)?'🍎':/pan/i.test(n)?'🍞':'🛒';
const unit=u=>({piece:'pzas',package:'paq.',dozen:'docenas'}[u]||u);
function read(key,fallback){try{return JSON.parse(localStorage.getItem(key))??fallback}catch{return fallback}}
const demoItems=()=>[{client_item_id:crypto.randomUUID(),name:'Leche',quantity:2,unit:'L',notes:null},{client_item_id:crypto.randomUUID(),name:'Huevos',quantity:12,unit:'piece',notes:null},{client_item_id:crypto.randomUUID(),name:'Arroz',quantity:1,unit:'kg',notes:null}];
let savedProducts=read('barasu-wishlist',[]);if(!Array.isArray(savedProducts))savedProducts=[];
let requestedVisuals=false,lastPriceQuestion=null,lastComparison=null;
let purchases=read('barasu-purchases',[]),draftCollapsed=false;

if(!Array.isArray(purchases))purchases=[];
let removedPurchases=read('barasu-removed-purchases',[]);
if(!Array.isArray(removedPurchases))removedPurchases=[];
let priceScope=read('baras-price-scope','published');
let items=read('baras-draft-v2',[]),history=read('super-history',[]),postal=read('super-postal',''),busy=false,plan=null,liveMode=true,fulfillment=read('super-fulfillment','delivery');
function queryLocation(){return fulfillment==='pickup'?{postal_code:'52994',fulfillment:'pickup',pickup_store:'chedraui-bellavista'}:postal?{postal_code:postal,fulfillment:'delivery'}:null;}
if(!Array.isArray(items))items=[];if(!Array.isArray(history))history=[];
if(items.length)requestedVisuals=true;
function save(){try{localStorage.setItem('baras-draft-v2',JSON.stringify(items));localStorage.setItem('super-history',JSON.stringify(history.slice(0,30)));localStorage.setItem('super-postal',JSON.stringify(postal));localStorage.setItem('super-fulfillment',JSON.stringify(fulfillment));}catch{notice('No se pudo guardar en este navegador.')}}
function notice(text){$('notice').innerHTML=text?`<div class="notice">${esc(text)}</div>`:''}
let chat=read('barasu-chat',[]);if(!Array.isArray(chat))chat=[];
function bubble(text,role,persist=true){const div=document.createElement('div');div.className='bubble '+role;div.textContent=text;$('conversation').append(div);if(persist){chat=[...chat,{text:String(text),role}].slice(-30);try{localStorage.setItem('barasu-chat',JSON.stringify(chat))}catch{}}}
function clearChat(){chat=[];$('conversation').innerHTML='';try{localStorage.removeItem('barasu-chat')}catch{}}
function view(name){$('weekly-view').hidden=name!=='weekly';$('savings-view').hidden=name!=='savings';if(name==='weekly'){weekly.setDraft(items);weekly.show();}if(name==='savings')renderSavingsStats();$('agent-view').hidden=name!=='agent';$('history-view').hidden=name!=='history';$('composer').hidden=name!=='agent';document.querySelectorAll('[data-view]').forEach(b=>b.classList.toggle('active',b.dataset.view===name));if(name==='history'){renderWishlist();renderHistory();renderSavingsStats()}}
function render(){
 save();
 if(requestedVisuals&&items.length)$('conversation').querySelector('.welcome')?.remove();
 const legacyUnspecified=items.length>=4&&items.every(i=>i.quantity===1&&i.unit==='piece');
 $('draft').innerHTML=requestedVisuals&&items.length&&draftCollapsed?`<button type="button" class="draft-chip" id="draft-expand"><span>Mi lista · ${items.length} ${items.length===1?'producto':'productos'}</span><span>Ver lista</span></button>`:requestedVisuals&&items.length?`<div class="draft-card"><div class="card-top"><h3>Mi lista</h3><span class="count">${items.length} ${items.length===1?'producto':'productos'}</span></div><div class="draft-carousel-nav"><span>Desliza para ver todos</span><div><button type="button" id="draft-prev" aria-label="Productos anteriores">‹</button><button type="button" id="draft-next" aria-label="Productos siguientes">›</button></div></div><div class="products" id="draft-products" role="region" aria-label="Productos de tu lista" tabindex="0">${items.map(i=>`<div class="product"><span class="emoji">${emoji(i.name)}</span><strong>${esc(i.name)}</strong><small>${legacyUnspecified||i.unit==='package'&&i.quantity===1?'Presentación por elegir':`${esc(i.quantity)} ${esc(unit(i.unit))}`}</small></div>`).join('')}</div><button class="primary full" id="compare">Comparar precios <span style="float:right">→</span></button><button class="secondary outline full" id="edit">Editar productos</button></div>`:'';
 const strip=$('draft-products');
 if(strip){
  const previous=$('draft-prev'),next=$('draft-next');
  const sync=()=>{previous.disabled=strip.scrollLeft<=2;next.disabled=strip.scrollLeft+strip.clientWidth>=strip.scrollWidth-2};
  previous.onclick=()=>strip.scrollBy({left:-strip.clientWidth*.8,behavior:'smooth'});
  next.onclick=()=>strip.scrollBy({left:strip.clientWidth*.8,behavior:'smooth'});
  strip.addEventListener('scroll',sync,{passive:true});
  requestAnimationFrame(sync);
 }
 $('compare')?.addEventListener('click',()=>{weekly.setDraft(items);view('weekly');weekly.autoSelect()});
 $('draft-expand')?.addEventListener('click',()=>{draftCollapsed=false;render()});
 $('edit')?.addEventListener('click',editor);
 if(busy)lock(true);
}
function lock(value){busy=value;document.querySelectorAll('button,input').forEach(e=>{if(!e.closest('#modal')&&!e.closest('#voice-panel')&&e.id!=='voice-open')e.disabled=value});}
const OFFLINE='No hay conexión con Barasu. Revisa tu internet e intenta de nuevo; tu lista se conserva.';
function apiError(r,d){return r.status===429?'Llegamos al límite de búsquedas por ahora. Intenta de nuevo en un rato.':d?.reply||d?.message||'No se pudo completar. Intenta de nuevo.'}
async function request(body){lock(true);notice('');const loading=document.createElement('div');loading.className='loading';loading.textContent=body.action==='product_prices'?'Buscando y comparando precios publicados':body.action==='compare'?'Comparando tu lista':'Organizando tu lista';$('conversation').append(loading);try{const r=await fetch('/v1/chat/search',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(95000)});const d=await r.json().catch(()=>null);if(!r.ok||!d||(d.status==='error'&&!d.plan&&!d.comparison))throw Error(apiError(r,d));return d;}catch(e){notice(e.name==='TimeoutError'?'El agente tardó más de lo esperado. Intenta de nuevo.':e instanceof TypeError?OFFLINE:e.message);return null}finally{loading.remove();lock(false)}}
async function requestWeekly(query){
 let response;try{response=await fetch('/v1/chat/search',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'product_prices',message:query,items:[],location:queryLocation(),price_scope:'published'}),signal:AbortSignal.timeout(95000)})}catch(e){throw e.name==='TimeoutError'?e:Error(OFFLINE)}
 const data=await response.json().catch(()=>null);
 if(!data||(!response.ok&&!data.comparison))throw Error(apiError(response,data));
 return data;
}
async function send(text){
 if(busy||!text.trim())return;
 view('agent');$('conversation').querySelector('.welcome')?.remove();bubble(text,'user');$('message').value='';
 plan=null;$('plan').innerHTML='';
 if(/\b(elige|selecciona|escoge|recomienda|decide|escoger|seleccionar|elegir)\b/i.test(text)&&/\b(opciones|productos|lista|por m[ií]|mejor(?:es)? precio|m[aá]s barato)\b/i.test(text)){
   const reply=weekly.autoSelect();
   bubble(reply,'assistant');
   view('weekly');
   return;
 }
 let priceQuestion=/precio|barat[oa]|cu[aá]nto cuesta|compar[aá]/i.test(text)&&!/s[uú]per|semanal|mi lista/i.test(text);
 if(priceQuestion)lastPriceQuestion=text;
 let d=await request({action:priceQuestion?'product_prices':'update_draft',message:text,items,location:queryLocation(),...(priceQuestion?{price_scope:priceScope}:{})});
 if(d&&priceQuestion&&!d.comparison&&d.status==='partial'&&/un producto para comparar/i.test(d.reply)){priceQuestion=false;d=await request({action:'update_draft',message:text,items,location:queryLocation()});}
 if(!d)return;
 bubble(d.reply,'assistant');
 if(priceQuestion){if(d.comparison){draftCollapsed=true;lastComparison=d.comparison;render();renderComparison(d.comparison);}else render();}
 else {items=d.draft_items;requestedVisuals=true;draftCollapsed=false;weekly.setDraft(items);render();if(items.length>1)void weekly.prefetch();}
 if(d.errors.length)notice([...new Set(d.errors.map(e=>e.message))].join(' '));
}
function productPhoto(listing){return listing.imageUrl?`<img class="product-photo" src="${esc(listing.imageUrl)}" alt="${esc(listing.productName)}" loading="lazy" referrerpolicy="no-referrer">`:'<span class="product-photo photo-fallback" aria-label="Sin imagen disponible">🛒</span>';}
function renderComparison(c){
 c.location=queryLocation();lastComparison=c;
 if(!c.offers.length){$('plan').innerHTML=`<div class="result"><h3>${c.scope==='local'?'Sin disponibilidad confirmada · CP '+esc(c.requested_postal_code):'No se encontraron precios para esta consulta'}</h3><p>Las tiendas no confirmaron la zona. Puedes consultar precios publicados como referencia, sin garantía de disponibilidad local.</p><button class="secondary full" id="published-prices">Ver precios publicados</button></div>`;$('published-prices').hidden=c.scope!=='local';$('published-prices').onclick=()=>{priceScope='published';if(lastPriceQuestion)void send(lastPriceQuestion)};return;}
 $('plan').innerHTML=`<section class="price-comparison"><div class="card-top"><h3>${emoji(c.query)} ${esc(c.query)}</h3><span class="count">${c.offers.length} opciones</span></div><p class="price-scope">${c.data_mode==='demo'?'DEMO · Precios de ejemplo':(c.scope==='local'?'Disponibilidad confirmada al consultar':'Precios publicados')} ${c.scope==='local'?'':'· disponibilidad local sin confirmar'}${c.requested_postal_code?' · CP '+esc(c.requested_postal_code):''}</p><p class="comparison-help">Compara el precio por unidad. Las marcas y presentaciones pueden ser diferentes; gramos y mililitros no son equivalentes.</p><table class="price-table"><thead><tr><th>Opción</th><th>Precio</th><th>Por unidad</th></tr></thead><tbody>${c.offers.map(o=>`<tr class="${(o.listing.productUrl===c.winner_url||(c.unit_winners||[]).some(w=>w.winner_url===o.listing.productUrl))?'winner-row':''}"><td><div class="product-with-photo">${productPhoto(o.listing)}<div><a href="${esc(o.listing.productUrl)}" target="_blank" rel="noopener noreferrer">${esc(o.listing.retailer)}</a><small>${esc(o.listing.productName)}</small>${(o.listing.productUrl===c.winner_url||(c.unit_winners||[]).some(w=>w.winner_url===o.listing.productUrl))?`<span class="winner-label">Menor precio / 100 ${esc(unit(o.basis))}</span>`:''}</div></div></td><td>${money(o.listing.priceCents)}</td><td><strong>${money(o.unit_price_cents_per_100)}</strong><small>/ 100 ${esc(unit(o.basis))}</small>${c.data_mode==='live'?`<button class="add-selection" data-select-offer="${esc(o.listing.productUrl)}">♡ Guardar</button>`:''}</td></tr>`).join('')}</tbody></table><details><summary>Ver detalle, sucursales y fechas</summary>${c.offers.map((o,n)=>`<article class="price-option ${(o.listing.productUrl===c.winner_url||(c.unit_winners||[]).some(w=>w.winner_url===o.listing.productUrl))?'best-price':''}"><div class="price-option-top"><strong>${esc(o.listing.retailer)}</strong>${(o.listing.productUrl===c.winner_url||(c.unit_winners||[]).some(w=>w.winner_url===o.listing.productUrl))?'<span class="best-badge">Menor precio por unidad</span>':''}</div><h4>${esc(o.listing.productName)}</h4><div class="price-pair"><strong>${money(o.listing.priceCents)}</strong><span>${money(o.unit_price_cents_per_100)} / 100 ${esc(o.basis)}</span></div><p>${esc(o.listing.quantity)} ${esc(unit(o.listing.unit))} por presentación${o.listing.storeName?' · Fuente: '+esc(o.listing.storeName):''}</p><div class="price-meter"><span style="width:${Math.max(8,Math.round(c.offers[0].unit_price_cents_per_100/o.unit_price_cents_per_100*100))}%"></span></div><small>Consultado: ${esc(new Date(o.listing.checkedAt).toLocaleString('es-MX'))}</small><a href="${esc(o.listing.productUrl)}" target="_blank" rel="noopener noreferrer">Ver producto en la tienda ↗</a></article>`).join('')}</details><p class="comparison-help">La comparación cubre las opciones que respondieron. El precio final y las existencias se confirman en la tienda.</p></section>`;
 $('plan').querySelectorAll('[data-select-offer]').forEach(b=>b.onclick=()=>saveOffer(c.offers.find(o=>o.listing.productUrl===b.dataset.selectOffer),c,b));
 $('plan').querySelectorAll('img.product-photo').forEach(img=>img.addEventListener('error',()=>{const fallback=document.createElement('span');fallback.className='product-photo photo-fallback';fallback.textContent='🛒';fallback.setAttribute('aria-label','Imagen no disponible');img.replaceWith(fallback)},{once:true}));
 $('plan').scrollIntoView({behavior:'smooth',block:'start'});
}
function open(content){$('modal-content').innerHTML=content;$('modal').showModal()}
function editor(){open(`<h2>Editar tu lista</h2><p style="color:var(--muted);font-size:13px">Ajusta los productos antes de comparar.</p><div id="edit-rows">${items.map((i,n)=>`<div class="edit-row" data-index="${n}"><input aria-label="Producto ${n+1}" value="${esc(i.name)}" maxlength="160"><input aria-label="Cantidad ${n+1}" type="number" min="0.001" step="0.001" value="${i.quantity}"><select aria-label="Unidad ${n+1}">${['piece','g','kg','ml','L','package','dozen'].map(u=>`<option value="${u}" ${u===i.unit?'selected':''}>${unit(u)}</option>`).join('')}</select><input class="edit-notes" aria-label="Detalles ${n+1}" maxlength="500" placeholder="Marca o detalles opcionales" value="${esc(i.notes||'')}"><button aria-label="Eliminar ${esc(i.name)}" class="remove-row">×</button></div>`).join('')}</div><p id="edit-error" class="field-error" role="alert"></p><button id="save-edit" class="primary full">Guardar cambios</button>`);document.querySelectorAll('.remove-row').forEach(b=>b.onclick=()=>b.parentElement.remove());$('save-edit').onclick=()=>{const next=[...document.querySelectorAll('.edit-row')].map(row=>{const fields=row.querySelectorAll('input,select');return {...items[Number(row.dataset.index)],name:fields[0].value.trim(),quantity:Number(fields[1].value),unit:fields[2].value,notes:fields[3].value.trim()||null}});{const rows=[...document.querySelectorAll('.edit-row')];let bad=false;next.forEach((i,n)=>{const f=rows[n]?.querySelectorAll('input')??[];const badName=!i.name,badQty=!Number.isFinite(i.quantity)||i.quantity<=0||i.quantity>100000;f[0]?.setAttribute('aria-invalid',String(badName));f[1]?.setAttribute('aria-invalid',String(badQty));bad||=badName||badQty});if(bad){$('edit-error').textContent='Revisa los campos marcados: cada producto necesita nombre y una cantidad mayor que 0.';return}}items=next;plan=null;$('plan').innerHTML='';render();$('modal').close()};}
function savedLists(){const weeklyLists=read('barasu-weekly-history',[]);return [...(Array.isArray(weeklyLists)?weeklyLists:[]).filter(h=>h&&Array.isArray(h.items)&&h.items.length).map(h=>({id:h.id,date:h.date,items:h.items,total:h.total,stores:h.stores??[],demo:!!h.demo})),...history.filter(h=>h?.plan&&Array.isArray(h.items)).map(h=>({id:h.id,date:h.date,items:h.items,total:h.plan.total_price_cents,stores:h.plan.stores.map(s=>s.retailer),demo:h.plan.stores.some(s=>s.items.some(i=>i.data_status==='demo'))}))]}
function renderHistory(){const lists=savedLists();$('history').innerHTML=`<div class="section-title small"><h3>Listas anteriores</h3></div>`+(lists.length?lists.map(h=>`<article class="history-card"><h3>🛍️ &nbsp; ${esc(new Date(h.date).toLocaleDateString('es-MX',{day:'numeric',month:'long'}))}</h3><div class="total">${money(h.total)}</div><p>${h.items.map(i=>esc(i.name)).join(', ')}<br>${esc(h.stores.join(' + '))} · ${h.demo?'Precios de ejemplo':'Precios sujetos a actualización'}</p><button class="secondary" data-repeat="${esc(h.id)}">Repetir esta lista ↗</button></article>`).join(''):'<div class="empty"><span>🛍️</span>Aún no tienes listas anteriores.<br>Cuando elijas dónde comprar en Mi lista, aparecerá aquí para repetirla.</div>');document.querySelectorAll('[data-repeat]').forEach(b=>b.onclick=()=>reuse(b.dataset.repeat))}
function reuse(id){requestedVisuals=true;const h=savedLists().find(h=>h.id===id);if(!h)return;items=structuredClone(h.items).map(i=>({...i,client_item_id:crypto.randomUUID()}));plan=null;$('plan').innerHTML='';clearChat();bubble('Recuperé tu lista. Puedes editarla y comparar los precios otra vez.','assistant');view('agent');render()}
$('chat').onsubmit=e=>{e.preventDefault();void send($('message').value)};
function showDemo(){requestedVisuals=true;items=demoItems();plan=null;$('plan').innerHTML='';clearChat();bubble('Aquí tienes una lista demo para probar la comparación. Puedes editarla antes de continuar.','assistant');view('agent');render()}
$('example').onclick=showDemo;
$('repeat').onclick=()=>{const l=savedLists();l.length?reuse(l[0].id):view('history')};
$('add').onclick=()=>{open('<h2>Agregar a tu lista</h2><button class="menu-row" id="sample-menu"><span>✦</span><div><strong>Productos frecuentes</strong><small>Elige de tus comparaciones guardadas</small></div></button><button class="menu-row" id="history-menu"><span>◷</span><div><strong>Compras anteriores</strong><small>Reutiliza una lista guardada</small></div></button><button class="menu-row" id="write-menu"><span>☷</span><div><strong>Escribir una lista</strong><small>Agrega varios productos a la vez</small></div></button>');$('sample-menu').onclick=frequentMenu;$('history-menu').onclick=()=>{$('modal').close();view('history')};$('write-menu').onclick=()=>{$('modal').close();$('message').focus()};};
$('settings').onclick=()=>{open(`<div class="location-sheet"><h2>Tu ubicación</h2><label class="field">Código postal<input id="postal" inputmode="numeric" autocomplete="postal-code" maxlength="5" placeholder="Ej. 06700" value="${esc(postal)}" aria-describedby="postal-error"></label><p id="postal-error" class="field-error" role="alert"></p><button id="detect-location" class="secondary full">Usar mi ubicación actual</button><p id="location-status" role="status"></p><fieldset class="choice-group"><legend>¿Cómo vas a comprar?</legend><label class="choice"><input type="radio" name="fulfillment" value="delivery" ${fulfillment!=='pickup'?'checked':''}><span>Entrega a domicilio<small>Usamos tu código postal.</small></span></label><label class="choice"><input type="radio" name="fulfillment" value="pickup" ${fulfillment==='pickup'?'checked':''}><span>Recoger en Chedraui Bellavista<small>Blvd. Bellavista 22, Tlalnepantla · CP 52994</small></span></label></fieldset><label class="choice"><input type="checkbox" id="price-local" ${priceScope==='local'?'checked':''}><span>Solo precios disponibles en mi zona<small>Si lo desactivas verás precios publicados en línea, sin confirmar existencias para tu CP.</small></span></label><button class="primary full" id="save-postal">Guardar ubicación</button><p class="location-fineprint">Con tu permiso, enviamos tus coordenadas a OpenStreetMap solo para sugerir tu CP; guardamos únicamente el CP. Si una tienda pide dirección, sucursal o verificación, te lo diremos sin mostrarte precios de otra zona. <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">© OpenStreetMap contributors</a></p></div>`);const fulfillmentValue=()=>document.querySelector('input[name=fulfillment]:checked')?.value||'delivery';$('postal').oninput=()=>{$('price-local').checked=true;$('postal').removeAttribute('aria-invalid');$('postal-error').textContent=''};document.querySelectorAll('input[name=fulfillment]').forEach(r=>r.onchange=()=>{$('price-local').checked=true});attachLocation({button:$('detect-location'),status:$('location-status'),input:$('postal'),confirmButton:$('save-postal'),dialog:$('modal'),onDetected:()=>{document.querySelector('input[name=fulfillment][value=delivery]').checked=true;$('price-local').checked=true}});$('save-postal').onclick=()=>{const value=$('postal').value.trim();if(value&&!/^\d{5}$/.test(value)){$('postal').setAttribute('aria-invalid','true');$('postal-error').textContent='Escribe un código postal de cinco dígitos.';$('postal').focus();return}const nextFulfillment=fulfillmentValue();if(value!==postal||nextFulfillment!==fulfillment)lastComparison=null;postal=value;fulfillment=nextFulfillment;weekly.invalidateLocation();updateLocationLabel();priceScope=$('price-local').checked?'local':'published';localStorage.setItem('baras-price-scope',JSON.stringify(priceScope));clearChat();bubble(priceScope==='local'?'Ubicación actualizada. La siguiente consulta buscará precios disponibles para CP '+(queryLocation()?.postal_code??'sin definir')+'.':'Ubicación actualizada. Verás precios publicados en línea, sin confirmar existencias en tu zona.','assistant');plan=null;$('plan').innerHTML='';notice('');save();$('modal').close()}};
$('close').onclick=()=>$('modal').close();document.querySelectorAll('[data-view]').forEach(b=>b.onclick=()=>view(b.dataset.view));

if(chat.length){$('conversation').querySelector('.welcome')?.remove();for(const m of chat)if(m&&typeof m.text==='string'&&['user','assistant'].includes(m.role))bubble(m.text,m.role,false)}
render();fetch('/health').then(r=>r.json()).then(h=>{liveMode=h.mode==='live';$('price-mode').textContent=h.mode==='demo'?'Precios de demostración':'Precios sujetos a actualización';$('connection').textContent=(h.mode==='demo'?'Modo de demostración':'Listo para ayudarte')}).catch(()=>{$('connection').textContent='Sin conexión al backend'});

$('profile').onclick=()=>view('savings');

function frequentMenu(){const counts=new Map();for(const h of savedLists())for(const i of h.items){const key=[i.name.toLowerCase(),i.unit,i.notes||''].join('|');const prev=counts.get(key);counts.set(key,{item:i,count:(prev?.count||0)+1})}const frequent=[...counts.values()].sort((a,b)=>b.count-a.count).slice(0,20);open('<h2>Productos frecuentes</h2>'+(!frequent.length?'<p>Compara una lista para empezar a guardar tus productos frecuentes.</p>':frequent.map((v,n)=>`<button class="menu-row" data-frequent="${n}"><span>${emoji(v.item.name)}</span><div><strong>${esc(v.item.name)}</strong><small>${v.item.quantity} ${esc(unit(v.item.unit))} · ${v.count} comparaciones</small></div></button>`).join('')));document.querySelectorAll('[data-frequent]').forEach(b=>b.onclick=()=>{if(items.length>=20){notice('Puedes comparar hasta 20 productos.');$('modal').close();return}requestedVisuals=true;items.push({...structuredClone(frequent[Number(b.dataset.frequent)].item),client_item_id:crypto.randomUUID()});plan=null;$('plan').innerHTML='';view('agent');render();$('modal').close()})}

function saveSavings(){localStorage.setItem('barasu-purchases',JSON.stringify(purchases));localStorage.setItem('barasu-removed-purchases',JSON.stringify(removedPurchases));}
function renderSavingsStats(){
 const estimates=read('barasu-weekly-history',[]).filter(entry=>!entry.demo&&!purchases.some(purchase=>purchase.id===entry.id));
 const root=$('savings-stats');
 root.innerHTML=savingsMarkup(purchases,estimates,removedPurchases.length,money,esc);
 root.querySelector('#savings-open-list')?.addEventListener('click',()=>view('weekly'));
 root.querySelectorAll('[data-delete-purchase]').forEach(button=>button.onclick=()=>{
  if(!confirm('¿Eliminar este registro de compra y su estadística?'))return;
  removedPurchases.push(purchases.find(purchase=>purchase.id===button.dataset.deletePurchase));
  purchases=purchases.filter(purchase=>purchase.id!==button.dataset.deletePurchase);
  saveSavings();renderSavingsStats();
 });
 root.querySelector('#restore-purchase')?.addEventListener('click',()=>{
  const purchase=removedPurchases.pop();
  if(purchase&&!purchases.some(item=>item.id===purchase.id))purchases.unshift(purchase);
  saveSavings();renderSavingsStats();
 });
}
const weekly=mountWeekly({root:$('weekly-root'),onWrite:()=>{view('agent');$('message').focus()},location:queryLocation,
 search:requestWeekly,
 onRegister:(snapshot,onSaved)=>{if(purchases.some(p=>p.id===snapshot.id)){notice('Esta lista ya tiene una compra registrada. Inicia una nueva semana para otro registro.');return;}
 open(`<h2>${snapshot.referenceCents===null?'Registrar mi compra':'Registrar mi ahorro'}</h2><p>Estimado: ${money(snapshot.totalCents)}. Registra solo los productos de esta lista, sin envío ni artículos extra.</p><label class="field">Total que realmente pagaste (MXN)<input id="week-paid" inputmode="decimal" placeholder="Total de tu ticket"></label><p>${snapshot.referenceCents===null?'Falta una referencia habitual completa: guardaremos el gasto, sin calcular ahorro.':'Tu referencia habitual: '+money(snapshot.referenceCents)}</p><button class="primary full" id="week-confirm">Confirmar compra realizada</button><p id="week-confirm-error" role="status"></p>`);
 let confirmedOdd=false;$('week-paid').oninput=()=>{confirmedOdd=false;$('week-confirm-error').textContent=''};$('week-confirm').onclick=()=>{const paid=parseMoney($('week-paid').value);if(paid===null){$('week-confirm-error').textContent='Escribe el importe pagado.';return;}if(!confirmedOdd&&snapshot.totalCents>0&&Math.abs(paid-snapshot.totalCents)>snapshot.totalCents*.5){confirmedOdd=true;$('week-confirm-error').textContent='Ese total se aleja mucho del estimado ('+money(snapshot.totalCents)+'). Revísalo o toca «Confirmar» otra vez para guardarlo así.';return;}if(purchases.some(p=>p.id===snapshot.id))return;
 const purchase=recordWeeklyPurchase(snapshot,purchases,paid);
 try{const next=[purchase,...purchases];localStorage.setItem('barasu-purchases',JSON.stringify(next));purchases=next;$('modal').close();onSaved();view('savings')}catch{$('week-confirm-error').textContent='No pudimos guardar. Tu compra no se registró.';}};
 }});
// Keep startup free of unsolicited product cards. Show a saved basket after a user action.
// Previous purchase records remain accessible in the history disclosure.

mountVoice({
 saveTool:async parameters=>{
   const offer=lastComparison?.offers.find(o=>o.listing.productUrl===parameters?.product_url);
   if(!offer||lastComparison.data_mode!=='live')return {error:'El producto no pertenece a la última búsqueda. Busca de nuevo antes de guardarlo.'};
   try{const product=saveProduct(savedProducts,offer,lastComparison);const next=[product,...savedProducts.filter(p=>p.id!==product.id)];localStorage.setItem('barasu-wishlist',JSON.stringify(next));savedProducts=next;return {saved:true,product:product.name,retailer:product.retailer};}catch{return {saved:false,error:'No se pudo guardar en este dispositivo.'};}
 },
 onMessage:(text,role)=>{view('agent');$('conversation').querySelector('.welcome')?.remove();bubble(text,role)},
 runTool:async parameters=>{
  if(parameters?.action==='select_best'){
    view('weekly');
    return {reply:weekly.autoSelect(),status:'selection_in_progress'};
  }
  if(!parameters||typeof parameters.message!=='string'||!parameters.message.trim()||parameters.message.length>2000||!['product_prices','update_draft'].includes(parameters.action))return {error:'Parámetros inválidos.'};
  if(busy)return {error:'Espera la consulta actual antes de iniciar otra.'};
  view('agent');plan=null;$('plan').innerHTML='';
  const result=await request({action:parameters.action,message:parameters.message,items,location:queryLocation(),...(parameters.action==='product_prices'?{price_scope:priceScope}:{})});
  if(!result)return {error:'La consulta falló. No hay precios verificados.'};
  if(parameters.action==='product_prices'){lastPriceQuestion=parameters.message;if(result.comparison)renderComparison(result.comparison);render();}
  else{items=result.draft_items;requestedVisuals=true;weekly.setDraft(items);render();if(items.length>1)void weekly.prefetch();}
  // The voice agent receives the same source-backed reply as the visible UI.
  return {reply:result.reply,status:result.status,errors:result.errors,comparison:result.comparison??null,draft_items:result.draft_items};
 }
});

function saveOffer(offer,comparison,button){try{const product=saveProduct(savedProducts,offer,comparison);savedProducts=savedProducts.filter(p=>p.id!==product.id);savedProducts.unshift(product);localStorage.setItem('barasu-wishlist',JSON.stringify(savedProducts));if(button)button.textContent='✓ Guardado';notice('Guardado en Barasu. Puedes revisar el precio desde Guardados.')}catch(e){notice(e.message)}}
function renderWishlist(){
 $('wishlist').innerHTML=savedProducts.length?`<p class="comparison-help">Guardas dónde encontraste cada producto y el precio observado. Al actualizar comprobamos la misma oferta; no implica que siga siendo la más barata ni que haya existencias.</p>${savedProducts.map(p=>{const last=p.observations.at(-1),change=priceChange(p);return `<article class="history-card"><div class="product-with-photo">${productPhoto({imageUrl:p.image,productName:p.name})}<div><h3>${esc(p.name)}</h3><p>${esc(p.retailer)}</p><strong>${money(last.priceCents)}</strong></div></div><p>Consultado: ${esc(new Date(last.checkedAt).toLocaleString('es-MX'))}<br>${last.scope==='local'?'Zona confirmada al consultar':'Precio publicado · disponibilidad local sin confirmar'}${last.postal?' · CP '+esc(last.postal):''}</p><p>${change===null?'Primera observación para esta zona.':change<0?'Bajó '+money(-change)+' desde la observación anterior.':change>0?'Subió '+money(change)+' desde la observación anterior.':'Mismo precio que en la observación anterior.'}</p><a class="secondary" href="${esc(p.url)}" target="_blank" rel="noopener noreferrer">Ver en la tienda ↗</a><button class="secondary" data-refresh-saved="${esc(p.id)}">Actualizar precio</button><button class="secondary" data-compare-saved="${esc(p.id)}">Comparar otras tiendas</button><button class="secondary" data-remove-saved="${esc(p.id)}">Quitar de guardados</button><div id="saved-status-${esc(p.id)}" role="status"></div></article>`}).join('')}`:'<div class="empty">♡<h3>Guarda lo que encuentres</h3><p>Busca un producto y pulsa Guardar. Aquí podrás seguir su precio y abrirlo en la tienda.</p></div>';
 $('wishlist').querySelectorAll('[data-refresh-saved]').forEach(b=>b.onclick=()=>refreshSaved(b.dataset.refreshSaved));
 $('wishlist').querySelectorAll('[data-compare-saved]').forEach(b=>b.onclick=()=>{const p=savedProducts.find(p=>p.id===b.dataset.compareSaved);void send('Compara el precio de '+p.query)});
 $('wishlist').querySelectorAll('[data-remove-saved]').forEach(b=>b.onclick=()=>{const p=savedProducts.find(p=>p.id===b.dataset.removeSaved);savedProducts=savedProducts.filter(x=>x.id!==p.id);localStorage.setItem('barasu-wishlist',JSON.stringify(savedProducts));renderWishlist();const undo=document.createElement('button');undo.className='secondary';undo.textContent='Deshacer: '+p.name;undo.onclick=()=>{if(!savedProducts.some(x=>x.id===p.id))savedProducts.unshift(p);localStorage.setItem('barasu-wishlist',JSON.stringify(savedProducts));renderWishlist()};$('wishlist').prepend(undo)});
}
async function refreshSaved(id){
 if(busy)return;const p=savedProducts.find(p=>p.id===id);if(!p)return;
 const previous=p.observations.at(-1);const status=$('saved-status-'+id);status.textContent='Consultando la misma oferta…';
 const result=await request({action:'product_prices',message:p.query,items:[],location:previous.location??(previous.postal?{postal_code:previous.postal}:null),price_scope:previous.scope});
 const offer=result?.comparison?.offers.find(o=>o.listing.productUrl===p.url);
 if(!offer){status.textContent='No se pudo actualizar esta oferta. Conservamos el precio anterior y su fecha; no confirmamos disponibilidad.';return;}
 result.comparison.location=previous.location??null;saveOffer(offer,result.comparison);renderWishlist();
}

function updateLocationLabel(){const label=fulfillment==='pickup'?'Recoger: Bellavista · 52994':postal?'⌖ CP '+postal:'⌖ Elegir ubicación';$('settings').textContent=label;$('settings').setAttribute('aria-label','Configurar ubicación. '+label)}
updateLocationLabel();
document.addEventListener('error',e=>{const img=e.target;if(!(img instanceof HTMLImageElement)||!img.isConnected||!img.closest('#weekly-root,#plan,#wishlist'))return;const fallback=document.createElement('span');fallback.className='weekly-photo-fallback';fallback.setAttribute('aria-label','Imagen no disponible');fallback.textContent='🛒';img.replaceWith(fallback)},true);
