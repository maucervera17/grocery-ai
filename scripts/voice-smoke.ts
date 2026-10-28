// Real ElevenLabs session using a synthetic text turn, never microphone capture.
const key=process.env.ELEVENLABS_API_KEY,agent=process.env.ELEVENLABS_AGENT_ID;
if(!key||!agent)throw Error('Configure ElevenLabs first');
const auth=await fetch(`https://api.elevenlabs.io/v1/convai/conversation/get-signed-url?agent_id=${encodeURIComponent(agent)}`,{headers:{'xi-api-key':key}});
if(!auth.ok)throw Error(`Voice auth failed (${auth.status})`);
const {signed_url}=await auth.json() as {signed_url:string};
let chunks=0,toolCalls=0,toolFinished=false,afterTool='';
await new Promise<void>((resolve,reject)=>{
 const ws=new WebSocket(signed_url);
 const timer=setTimeout(()=>{ws.close();reject(Error('Voice timeout'));},150000);
 let querySent=false;
 ws.onopen=()=>ws.send(JSON.stringify({type:'conversation_initiation_client_data'}));
 ws.onerror=()=>{clearTimeout(timer);reject(Error('Voice transport error'));};
 ws.onmessage=async event=>{
  const m=JSON.parse(String(event.data));
  if(!['audio','ping','agent_response'].includes(m.type))console.log('event',m.type,Object.keys(m));
  if(m.type==='ping')ws.send(JSON.stringify({type:'pong',event_id:m.ping_event.event_id}));
  if(m.type==='conversation_initiation_metadata'&&!querySent){querySent=true;setTimeout(()=>ws.send(JSON.stringify({type:'user_message',text:'Hola, ¿en qué tienda está más barato el queso parmesano?'})),1500);}
  if(m.type==='audio')chunks++;
  if(m.type==='client_tool_call'){
   toolCalls++;
   const call=m.client_tool_call;
   if(call.tool_name!=='barasu_search')throw Error('Unexpected voice tool');
   console.log('ElevenLabs invoked Barasu product search');
   const response=await fetch('http://127.0.0.1:3000/v1/chat/search',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:call.parameters.action,message:call.parameters.message,items:[],price_scope:'published',location:null})});
   const result=await response.json();
   ws.send(JSON.stringify({type:'client_tool_result',tool_call_id:call.tool_call_id,result:JSON.stringify(result),is_error:!response.ok}));
   toolFinished=true;
  }
  if(m.type==='agent_response'){
   const text=m.agent_response_event.agent_response;
   console.log('Agent:',text);
   if(toolFinished){afterTool=text;setTimeout(()=>{clearTimeout(timer);ws.close();if(chunks>0&&toolCalls>0&&afterTool)resolve();else reject(Error('Missing audio or tool result'));},4000);}
  }
 };
});
console.log(JSON.stringify({passed:true,audio_chunks:chunks,tool_calls:toolCalls,source_response_received:Boolean(afterTool)}));
