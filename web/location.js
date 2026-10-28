export function attachLocation({button,status,input,confirmButton,onDetected,dialog,geolocation=navigator.geolocation,fetcher=fetch}) {
 let generation=0,controller=null,timer=null;
 const invalidate=()=>{generation++;clearTimeout(timer);controller?.abort();button.disabled=false;confirmButton.disabled=false;};
 dialog.addEventListener('close',invalidate,{once:true});
 button.onclick=()=>{
  if(!geolocation){status.textContent='Este navegador no admite ubicación. Escribe tu CP.';return;}
  const id=++generation;button.disabled=true;confirmButton.disabled=true;status.textContent='Buscando tu ubicación…';
  timer=setTimeout(()=>{if(id!==generation)return;invalidate();status.textContent='La ubicación tardó demasiado. Reintenta o escribe tu CP.';},25000);
  geolocation.getCurrentPosition(async position=>{
   if(id!==generation)return;
   if(!Number.isFinite(position.coords.accuracy)||position.coords.accuracy<0||Math.abs(Date.now()-position.timestamp)>60000){invalidate();status.textContent='La posición no es reciente. Reintenta o escribe tu CP.';return;}
   controller=new AbortController();
   try{
    const response=await fetcher('/v1/location/resolve',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({latitude:position.coords.latitude,longitude:position.coords.longitude}),signal:controller.signal});
    const data=await response.json();
    if(id!==generation)return;
    if(!response.ok)throw Error(data.message||'No se pudo resolver tu ubicación.');
    if(!/^\d{5}$/.test(data.postal_code))throw Error('No se obtuvo un CP válido.');
    input.value=data.postal_code;
    const accuracy=Math.round(position.coords.accuracy);
    status.textContent=`${data.area} · precisión aproximada ${accuracy} m. CP sugerido: ${data.postal_code}. Confírmalo antes de guardar.`;
    onDetected();
   }catch(error){if(id===generation)status.textContent=error.message||'No se pudo obtener la ubicación.';}
   finally{if(id===generation)invalidate();}
  },error=>{if(id!==generation)return;invalidate();status.textContent=error.code===1?'Permiso denegado. Activa ubicación en los ajustes del navegador o escribe tu CP.':error.code===3?'No llegó una posición a tiempo. Reintenta o escribe tu CP.':'Ubicación no disponible. Escribe tu CP.';},{enableHighAccuracy:true,maximumAge:0,timeout:15000});
 };
}
