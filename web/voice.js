// SDK is loaded only after the user opens voice mode.
export function mountVoice({runTool,saveTool,onMessage,loadSDK=()=>import('/voice-sdk.js'),micTimeoutMs=12000,sessionTimeoutMs=30000}) {
  const panel=document.getElementById('voice-panel'),status=document.getElementById('voice-status');
  const start=document.getElementById('voice-start'),stop=document.getElementById('voice-stop'),mute=document.getElementById('voice-mute');
  let conversation=null,epoch=0,muted=false,starting=false,toolBusy=false;
  const say=text=>{status.textContent=text;if(panel.dataset)panel.dataset.state=text.includes('hablando')?'speaking':text.includes('escucho')?'listening':text.includes('silenciado')?'muted':/Esperando|Solicitando|Abriendo|Consultando/.test(text)?'loading':'idle'};
  const withTimeout=(promise,ms,message)=>{let timer;return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error(message)),ms)})]).finally(()=>clearTimeout(timer));};
  async function end(){epoch++;starting=false;const old=conversation;conversation=null;start.disabled=false;stop.disabled=true;mute.disabled=true;muted=false;mute.textContent='Silenciar';say('Voz finalizada');if(old)await old.endSession().catch(()=>{});}
  document.getElementById('voice-open').onclick=async()=>{panel.hidden=!panel.hidden;document.getElementById('voice-open').setAttribute?.('aria-expanded',String(!panel.hidden));if(panel.hidden){await end();return;}say('Comprobando conexión…');try{const r=await fetch('/v1/voice/status');const d=await r.json();say(d.configured?'Listo para conversar':'ElevenLabs pendiente de configuración en el servidor.');start.disabled=!d.configured;}catch{say('No hay conexión con el servidor.');start.disabled=true;}};
  const close=document.getElementById('voice-close');if(close)close.onclick=async()=>{panel.hidden=true;document.getElementById('voice-open').setAttribute?.('aria-expanded','false');await end()};
  start.onclick=async()=>{
    if(starting||conversation)return;
    const id=++epoch;starting=true;start.disabled=true;stop.disabled=false;say('Esperando permiso de micrófono…');
    try {
      if(!navigator.mediaDevices?.getUserMedia)throw Error('Necesitas HTTPS o localhost y un navegador con micrófono.');
      const media=navigator.mediaDevices.getUserMedia({audio:true});
      media.then(stream=>{if(id!==epoch)stream.getTracks().forEach(t=>t.stop());}).catch(()=>{});
      const permission=await withTimeout(media,micTimeoutMs,'El micrófono no respondió en este navegador. Revisa el permiso o abre Barasu en Chrome.');permission.getTracks().forEach(t=>t.stop());
      if(id!==epoch)return;
      say('Solicitando sesión de voz…');
      const response=await withTimeout(fetch('/v1/voice/session',{method:'POST'}),sessionTimeoutMs,'ElevenLabs tardó demasiado en crear la sesión.'),data=await response.json();
      if(!response.ok)throw Error(data.message||'No se pudo iniciar la voz.');
      say('Abriendo canal de audio…');
      const {Conversation}=await withTimeout(loadSDK(),sessionTimeoutMs,'No pude cargar el módulo de voz. Recarga Barasu e intenta de nuevo.');
      if(id!==epoch)return;
      const connection=Conversation.startSession({
        conversationToken:data.conversation_token,connectionType:'webrtc',
        onMessage:({message,source})=>{if(id===epoch&&message)onMessage(message,source==='user'?'user':'assistant');},
        onModeChange:({mode})=>{if(id===epoch)say(mode==='speaking'?'Barasu está hablando':'Te escucho…');},
        onDisconnect:()=>{if(id===epoch)void end();},
        onError:()=>{if(id===epoch){void end();say('La conversación se interrumpió. Puedes volver a iniciar.');}},
        clientTools:{barasu_save:async parameters=>{if(id!==epoch)return 'La sesión terminó.';return JSON.stringify(await saveTool(parameters));},barasu_search:async parameters=>{
          if(id!==epoch)return JSON.stringify({error:'La sesión terminó.'});
          if(toolBusy)return JSON.stringify({error:'Hay una consulta en curso. Espera su respuesta.'});
          toolBusy=true;say('Consultando productos…');
          try{return JSON.stringify(await runTool(parameters));}catch{return JSON.stringify({error:'No se pudo completar la consulta. No hay precios confirmados.'});}finally{toolBusy=false;}
        }},
      });
      connection.then(active=>{if(id!==epoch)void active.endSession().catch(()=>{});}).catch(()=>{});
      const connected=await withTimeout(connection,sessionTimeoutMs,'ElevenLabs no abrió el canal de audio. Intenta de nuevo en Chrome.');
      if(id!==epoch){await connected.endSession();return;}
      conversation=connected;starting=false;mute.disabled=false;say('Te escucho…');
    } catch(error){if(id!==epoch)return;await end();say(error.name==='NotAllowedError'?'Permiso de micrófono denegado. Puedes seguir escribiendo.':error.message);}
  };
  stop.onclick=end;
  mute.onclick=()=>{if(!conversation)return;muted=!muted;conversation.setMicMuted(muted);mute.textContent=muted?'Activar micrófono':'Silenciar';say(muted?'Micrófono silenciado':'Te escucho…');};
  document.addEventListener('visibilitychange',()=>{if(document.hidden)void end();});
  window.addEventListener('pagehide',()=>{void end();});
}
