// SDK is loaded only after the user opens voice mode.
export function mountVoice({runTool,saveTool,onMessage,loadSDK=()=>import('/voice-sdk.js')}) {
  const panel=document.getElementById('voice-panel'),status=document.getElementById('voice-status');
  const start=document.getElementById('voice-start'),stop=document.getElementById('voice-stop'),mute=document.getElementById('voice-mute');
  let conversation=null,epoch=0,muted=false,starting=false,toolBusy=false;
  const say=text=>{status.textContent=text};
  async function end(){epoch++;starting=false;const old=conversation;conversation=null;start.disabled=false;stop.disabled=true;mute.disabled=true;muted=false;mute.textContent='Silenciar';say('Voz finalizada');if(old)await old.endSession().catch(()=>{});}
  document.getElementById('voice-open').onclick=async()=>{panel.hidden=!panel.hidden;if(panel.hidden){await end();return;}say('Comprobando conexión…');try{const r=await fetch('/v1/voice/status');const d=await r.json();say(d.configured?'Listo para conversar':'ElevenLabs pendiente de configuración en el servidor.');start.disabled=!d.configured;}catch{say('No hay conexión con el servidor.');start.disabled=true;}};
  start.onclick=async()=>{
    if(starting||conversation)return;
    const id=++epoch;starting=true;start.disabled=true;stop.disabled=false;say('Conectando…');
    try {
      if(!navigator.mediaDevices?.getUserMedia)throw Error('Necesitas HTTPS o localhost y un navegador con micrófono.');
      const permission=await navigator.mediaDevices.getUserMedia({audio:true});permission.getTracks().forEach(t=>t.stop());
      if(id!==epoch)return;
      const response=await fetch('/v1/voice/session',{method:'POST'}),data=await response.json();
      if(!response.ok)throw Error(data.message||'No se pudo iniciar la voz.');
      const {Conversation}=await loadSDK();
      if(id!==epoch)return;
      const connected=await Conversation.startSession({
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
      if(id!==epoch){await connected.endSession();return;}
      conversation=connected;starting=false;mute.disabled=false;say('Te escucho…');
    } catch(error){if(id!==epoch)return;await end();say(error.name==='NotAllowedError'?'Permiso de micrófono denegado. Puedes seguir escribiendo.':error.message);}
  };
  stop.onclick=end;
  mute.onclick=()=>{if(!conversation)return;muted=!muted;conversation.setMicMuted(muted);mute.textContent=muted?'Activar micrófono':'Silenciar';say(muted?'Micrófono silenciado':'Te escucho…');};
  document.addEventListener('visibilitychange',()=>{if(document.hidden)void end();});
  window.addEventListener('pagehide',()=>{void end();});
}
