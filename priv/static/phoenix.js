var C=a=>typeof a=="function"?a:function(){return a};var U=typeof self!="undefined"?self:null,R=typeof window!="undefined"?window:null,S=U||R||void 0,N="2.0.0",p={connecting:0,open:1,closing:2,closed:3},w=1e4,O=1e3,d={closed:"closed",errored:"errored",joined:"joined",joining:"joining",leaving:"leaving"},f={close:"phx_close",error:"phx_error",join:"phx_join",reply:"phx_reply",leave:"phx_leave"},H=[f.close,f.error,f.join,f.reply,f.leave],L={longpoll:"longpoll",websocket:"websocket"};var v=class{constructor(e,t,i,s){this.channel=e,this.event=t,this.payload=i||function(){return{}},this.receivedResp=null,this.timeout=s,this.timeoutTimer=null,this.recHooks=[],this.sent=!1}resend(e){this.timeout=e,this.reset(),this.send()}send(){this.hasReceived("timeout")||(this.startTimeout(),this.sent=!0,this.channel.socket.push({topic:this.channel.topic,event:this.event,payload:this.payload(),ref:this.ref,join_ref:this.channel.joinRef()}))}receive(e,t){return this.hasReceived(e)&&t(this.receivedResp.response),this.recHooks.push({status:e,callback:t}),this}reset(){this.cancelRefEvent(),this.ref=null,this.refEvent=null,this.receivedResp=null,this.sent=!1}matchReceive({status:e,response:t,_ref:i}){this.recHooks.filter(s=>s.status===e).forEach(s=>s.callback(t))}cancelRefEvent(){!this.refEvent||this.channel.off(this.refEvent)}cancelTimeout(){clearTimeout(this.timeoutTimer),this.timeoutTimer=null}startTimeout(){this.timeoutTimer&&this.cancelTimeout(),this.ref=this.channel.socket.makeRef(),this.refEvent=this.channel.replyEventName(this.ref),this.channel.on(this.refEvent,e=>{this.cancelRefEvent(),this.cancelTimeout(),this.receivedResp=e,this.matchReceive(e)}),this.timeoutTimer=setTimeout(()=>{this.trigger("timeout",{})},this.timeout)}hasReceived(e){return this.receivedResp&&this.receivedResp.status===e}trigger(e,t){this.channel.trigger(this.refEvent,{status:e,response:t})}};var j=class{constructor(e,t){this.callback=e,this.timerCalc=t,this.timer=null,this.tries=0}reset(){this.tries=0,clearTimeout(this.timer)}scheduleTimeout(){clearTimeout(this.timer),this.timer=setTimeout(()=>{this.tries=this.tries+1,this.callback()},this.timerCalc(this.tries+1))}};var A=class{constructor(e,t,i){this.state=d.closed,this.topic=e,this.params=C(t||{}),this.socket=i,this.bindings=[],this.bindingRef=0,this.timeout=this.socket.timeout,this.joinedOnce=!1,this.joinPush=new v(this,f.join,this.params,this.timeout),this.pushBuffer=[],this.stateChangeRefs=[],this.rejoinTimer=new j(()=>{this.socket.isConnected()&&this.rejoin()},this.socket.rejoinAfterMs),this.stateChangeRefs.push(this.socket.onError(()=>this.rejoinTimer.reset())),this.stateChangeRefs.push(this.socket.onOpen(()=>{this.rejoinTimer.reset(),this.isErrored()&&this.rejoin()})),this.joinPush.receive("ok",()=>{this.state=d.joined,this.rejoinTimer.reset(),this.pushBuffer.forEach(s=>s.send()),this.pushBuffer=[]}),this.joinPush.receive("error",()=>{this.state=d.errored,this.socket.isConnected()&&this.rejoinTimer.scheduleTimeout()}),this.onClose(()=>{this.rejoinTimer.reset(),this.socket.hasLogger()&&this.socket.log("channel",`close ${this.topic} ${this.joinRef()}`),this.state=d.closed,this.socket.remove(this)}),this.onError(s=>{this.socket.hasLogger()&&this.socket.log("channel",`error ${this.topic}`,s),this.isJoining()&&this.joinPush.reset(),this.state=d.errored,this.socket.isConnected()&&this.rejoinTimer.scheduleTimeout()}),this.joinPush.receive("timeout",()=>{this.socket.hasLogger()&&this.socket.log("channel",`timeout ${this.topic} (${this.joinRef()})`,this.joinPush.timeout),new v(this,f.leave,C({}),this.timeout).send(),this.state=d.errored,this.joinPush.reset(),this.socket.isConnected()&&this.rejoinTimer.scheduleTimeout()}),this.on(f.reply,(s,r)=>{this.trigger(this.replyEventName(r),s)})}join(e=this.timeout){if(this.joinedOnce)throw new Error("tried to join multiple times. 'join' can only be called a single time per channel instance");return this.timeout=e,this.joinedOnce=!0,this.rejoin(),this.joinPush}onClose(e){this.on(f.close,e)}onError(e){return this.on(f.error,t=>e(t))}on(e,t){let i=this.bindingRef++;return this.bindings.push({event:e,ref:i,callback:t}),i}off(e,t){this.bindings=this.bindings.filter(i=>!(i.event===e&&(typeof t=="undefined"||t===i.ref)))}canPush(){return this.socket.isConnected()&&this.isJoined()}push(e,t,i=this.timeout){if(t=t||{},!this.joinedOnce)throw new Error(`tried to push '${e}' to '${this.topic}' before joining. Use channel.join() before pushing events`);let s=new v(this,e,function(){return t},i);return this.canPush()?s.send():(s.startTimeout(),this.pushBuffer.push(s)),s}leave(e=this.timeout){this.rejoinTimer.reset(),this.joinPush.cancelTimeout(),this.state=d.leaving;let t=()=>{this.socket.hasLogger()&&this.socket.log("channel",`leave ${this.topic}`),this.trigger(f.close,"leave")},i=new v(this,f.leave,C({}),e);return i.receive("ok",()=>t()).receive("timeout",()=>t()),i.send(),this.canPush()||i.trigger("ok",{}),i}onMessage(e,t,i){return t}isLifecycleEvent(e){return H.indexOf(e)>=0}isMember(e,t,i,s){return this.topic!==e?!1:s&&s!==this.joinRef()&&this.isLifecycleEvent(t)?(this.socket.hasLogger()&&this.socket.log("channel","dropping outdated message",{topic:e,event:t,payload:i,joinRef:s}),!1):!0}joinRef(){return this.joinPush.ref}rejoin(e=this.timeout){this.isLeaving()||(this.socket.leaveOpenTopic(this.topic),this.state=d.joining,this.joinPush.resend(e))}trigger(e,t,i,s){let r=this.onMessage(e,t,i,s);if(t&&!r)throw new Error("channel onMessage callbacks must return the payload, modified or unmodified");let o=this.bindings.filter(n=>n.event===e);for(let n=0;n<o.length;n++)o[n].callback(r,i,s||this.joinRef())}replyEventName(e){return`chan_reply_${e}`}isClosed(){return this.state===d.closed}isErrored(){return this.state===d.errored}isJoined(){return this.state===d.joined}isJoining(){return this.state===d.joining}isLeaving(){return this.state===d.leaving}};var m=class{constructor(){this.states={complete:4}}static request(e,t,i,s,r,o,n){if(S.XDomainRequest){let h=new S.XDomainRequest;this.xdomainRequest(h,e,t,s,r,o,n)}else{let h=new S.XMLHttpRequest;this.xhrRequest(h,e,t,i,s,r,o,n)}}static xdomainRequest(e,t,i,s,r,o,n){e.timeout=r,e.open(t,i),e.onload=()=>{let h=this.parseJSON(e.responseText);n&&n(h)},o&&(e.ontimeout=o),e.onprogress=()=>{},e.send(s)}static xhrRequest(e,t,i,s,r,o,n,h){e.open(t,i,!0),e.timeout=o,e.setRequestHeader("Content-Type",s),e.onerror=()=>{h&&h(null)},e.onreadystatechange=()=>{if(e.readyState===this.states.complete&&h){let l=this.parseJSON(e.responseText);h(l)}},n&&(e.ontimeout=n),e.send(r)}static parseJSON(e){if(!e||e==="")return null;try{return JSON.parse(e)}catch(t){return console&&console.log("failed to parse JSON response",e),null}}static serialize(e,t){let i=[];for(var s in e){if(!Object.prototype.hasOwnProperty.call(e,s))continue;let r=t?`${t}[${s}]`:s,o=e[s];typeof o=="object"?i.push(this.serialize(o,r)):i.push(encodeURIComponent(r)+"="+encodeURIComponent(o))}return i.join("&")}static appendParams(e,t){if(Object.keys(t).length===0)return e;let i=e.match(/\?/)?"&":"?";return`${e}${i}${this.serialize(t)}`}};var y=class{constructor(e){this.endPoint=null,this.token=null,this.skipHeartbeat=!0,this.onopen=function(){},this.onerror=function(){},this.onmessage=function(){},this.onclose=function(){},this.pollEndpoint=this.normalizeEndpoint(e),this.readyState=p.connecting,this.poll()}normalizeEndpoint(e){return e.replace("ws://","http://").replace("wss://","https://").replace(new RegExp("(.*)/"+L.websocket),"$1/"+L.longpoll)}endpointURL(){return m.appendParams(this.pollEndpoint,{token:this.token})}closeAndRetry(){this.close(),this.readyState=p.connecting}ontimeout(){this.onerror("timeout"),this.closeAndRetry()}poll(){(this.readyState===p.open||this.readyState===p.connecting)&&m.request("GET",this.endpointURL(),"application/json",null,this.timeout,this.ontimeout.bind(this),e=>{if(e){var{status:t,token:i,messages:s}=e;this.token=i}else t=0;switch(t){case 200:s.forEach(r=>{setTimeout(()=>{this.onmessage({data:r})},0)}),this.poll();break;case 204:this.poll();break;case 410:this.readyState=p.open,this.onopen(),this.poll();break;case 403:this.onerror(),this.close();break;case 0:case 500:this.onerror(),this.closeAndRetry();break;default:throw new Error(`unhandled poll status ${t}`)}})}send(e){m.request("POST",this.endpointURL(),"application/json",e,this.timeout,this.onerror.bind(this,"timeout"),t=>{(!t||t.status!==200)&&(this.onerror(t&&t.status),this.closeAndRetry())})}close(e,t){this.readyState=p.closed,this.onclose()}};var g=class{constructor(e,t={}){let i=t.events||{state:"presence_state",diff:"presence_diff"};this.state={},this.pendingDiffs=[],this.channel=e,this.joinRef=null,this.caller={onJoin:function(){},onLeave:function(){},onSync:function(){}},this.channel.on(i.state,s=>{let{onJoin:r,onLeave:o,onSync:n}=this.caller;this.joinRef=this.channel.joinRef(),this.state=g.syncState(this.state,s,r,o),this.pendingDiffs.forEach(h=>{this.state=g.syncDiff(this.state,h,r,o)}),this.pendingDiffs=[],n()}),this.channel.on(i.diff,s=>{let{onJoin:r,onLeave:o,onSync:n}=this.caller;this.inPendingSyncState()?this.pendingDiffs.push(s):(this.state=g.syncDiff(this.state,s,r,o),n())})}onJoin(e){this.caller.onJoin=e}onLeave(e){this.caller.onLeave=e}onSync(e){this.caller.onSync=e}list(e){return g.list(this.state,e)}inPendingSyncState(){return!this.joinRef||this.joinRef!==this.channel.joinRef()}static syncState(e,t,i,s){let r=this.clone(e),o={},n={};return this.map(r,(h,l)=>{t[h]||(n[h]=l)}),this.map(t,(h,l)=>{let u=r[h];if(u){let c=l.metas.map(T=>T.phx_ref),E=u.metas.map(T=>T.phx_ref),_=l.metas.filter(T=>E.indexOf(T.phx_ref)<0),x=u.metas.filter(T=>c.indexOf(T.phx_ref)<0);_.length>0&&(o[h]=l,o[h].metas=_),x.length>0&&(n[h]=this.clone(u),n[h].metas=x)}else o[h]=l}),this.syncDiff(r,{joins:o,leaves:n},i,s)}static syncDiff(e,t,i,s){let{joins:r,leaves:o}=this.clone(t);return i||(i=function(){}),s||(s=function(){}),this.map(r,(n,h)=>{let l=e[n];if(e[n]=this.clone(h),l){let u=e[n].metas.map(E=>E.phx_ref),c=l.metas.filter(E=>u.indexOf(E.phx_ref)<0);e[n].metas.unshift(...c)}i(n,l,h)}),this.map(o,(n,h)=>{let l=e[n];if(!l)return;let u=h.metas.map(c=>c.phx_ref);l.metas=l.metas.filter(c=>u.indexOf(c.phx_ref)<0),s(n,l,h),l.metas.length===0&&delete e[n]}),e}static list(e,t){return t||(t=function(i,s){return s}),this.map(e,(i,s)=>t(i,s))}static map(e,t){return Object.getOwnPropertyNames(e).map(i=>t(i,e[i]))}static clone(e){return JSON.parse(JSON.stringify(e))}};var b={HEADER_LENGTH:1,META_LENGTH:4,KINDS:{push:0,reply:1,broadcast:2},encode(a,e){if(a.payload.constructor===ArrayBuffer)return e(this.binaryEncode(a));{let t=[a.join_ref,a.ref,a.topic,a.event,a.payload];return e(JSON.stringify(t))}},decode(a,e){if(a.constructor===ArrayBuffer)return e(this.binaryDecode(a));{let[t,i,s,r,o]=JSON.parse(a);return e({join_ref:t,ref:i,topic:s,event:r,payload:o})}},binaryEncode(a){let{join_ref:e,ref:t,event:i,topic:s,payload:r}=a,o=this.META_LENGTH+e.length+t.length+s.length+i.length,n=new ArrayBuffer(this.HEADER_LENGTH+o),h=new DataView(n),l=0;h.setUint8(l++,this.KINDS.push),h.setUint8(l++,e.length),h.setUint8(l++,t.length),h.setUint8(l++,s.length),h.setUint8(l++,i.length),Array.from(e,c=>h.setUint8(l++,c.charCodeAt(0))),Array.from(t,c=>h.setUint8(l++,c.charCodeAt(0))),Array.from(s,c=>h.setUint8(l++,c.charCodeAt(0))),Array.from(i,c=>h.setUint8(l++,c.charCodeAt(0)));var u=new Uint8Array(n.byteLength+r.byteLength);return u.set(new Uint8Array(n),0),u.set(new Uint8Array(r),n.byteLength),u.buffer},binaryDecode(a){let e=new DataView(a),t=e.getUint8(0),i=new TextDecoder;switch(t){case this.KINDS.push:return this.decodePush(a,e,i);case this.KINDS.reply:return this.decodeReply(a,e,i);case this.KINDS.broadcast:return this.decodeBroadcast(a,e,i)}},decodePush(a,e,t){let i=e.getUint8(1),s=e.getUint8(2),r=e.getUint8(3),o=this.HEADER_LENGTH+this.META_LENGTH-1,n=t.decode(a.slice(o,o+i));o=o+i;let h=t.decode(a.slice(o,o+s));o=o+s;let l=t.decode(a.slice(o,o+r));o=o+r;let u=a.slice(o,a.byteLength);return{join_ref:n,ref:null,topic:h,event:l,payload:u}},decodeReply(a,e,t){let i=e.getUint8(1),s=e.getUint8(2),r=e.getUint8(3),o=e.getUint8(4),n=this.HEADER_LENGTH+this.META_LENGTH,h=t.decode(a.slice(n,n+i));n=n+i;let l=t.decode(a.slice(n,n+s));n=n+s;let u=t.decode(a.slice(n,n+r));n=n+r;let c=t.decode(a.slice(n,n+o));n=n+o;let E=a.slice(n,a.byteLength),_={status:c,response:E};return{join_ref:h,ref:l,topic:u,event:f.reply,payload:_}},decodeBroadcast(a,e,t){let i=e.getUint8(1),s=e.getUint8(2),r=this.HEADER_LENGTH+2,o=t.decode(a.slice(r,r+i));r=r+i;let n=t.decode(a.slice(r,r+s));r=r+s;let h=a.slice(r,a.byteLength);return{join_ref:null,ref:null,topic:o,event:n,payload:h}}};var k=class{constructor(e,t={}){this.stateChangeCallbacks={open:[],close:[],error:[],message:[]},this.channels=[],this.sendBuffer=[],this.ref=0,this.timeout=t.timeout||w,this.transport=t.transport||S.WebSocket||y,this.establishedConnections=0,this.defaultEncoder=b.encode.bind(b),this.defaultDecoder=b.decode.bind(b),this.closeWasClean=!1,this.binaryType=t.binaryType||"arraybuffer",this.connectClock=1,this.transport!==y?(this.encode=t.encode||this.defaultEncoder,this.decode=t.decode||this.defaultDecoder):(this.encode=this.defaultEncoder,this.decode=this.defaultDecoder);let i=null;R&&R.addEventListener&&(R.addEventListener("pagehide",s=>{this.conn&&(this.disconnect(),i=this.connectClock)}),R.addEventListener("pageshow",s=>{i===this.connectClock&&(i=null,this.connect())})),this.heartbeatIntervalMs=t.heartbeatIntervalMs||3e4,this.rejoinAfterMs=s=>t.rejoinAfterMs?t.rejoinAfterMs(s):[1e3,2e3,5e3][s-1]||1e4,this.reconnectAfterMs=s=>t.reconnectAfterMs?t.reconnectAfterMs(s):[10,50,100,150,200,250,500,1e3,2e3][s-1]||5e3,this.logger=t.logger||null,this.longpollerTimeout=t.longpollerTimeout||2e4,this.params=C(t.params||{}),this.endPoint=`${e}/${L.websocket}`,this.vsn=t.vsn||N,this.heartbeatTimer=null,this.pendingHeartbeatRef=null,this.reconnectTimer=new j(()=>{this.teardown(()=>this.connect())},this.reconnectAfterMs)}replaceTransport(e){this.disconnect(),this.transport=e}protocol(){return location.protocol.match(/^https/)?"wss":"ws"}endPointURL(){let e=m.appendParams(m.appendParams(this.endPoint,this.params()),{vsn:this.vsn});return e.charAt(0)!=="/"?e:e.charAt(1)==="/"?`${this.protocol()}:${e}`:`${this.protocol()}://${location.host}${e}`}disconnect(e,t,i){this.connectClock++,this.closeWasClean=!0,this.reconnectTimer.reset(),this.teardown(e,t,i)}connect(e){this.connectClock++,e&&(console&&console.log("passing params to connect is deprecated. Instead pass :params to the Socket constructor"),this.params=C(e)),!this.conn&&(this.closeWasClean=!1,this.conn=new this.transport(this.endPointURL()),this.conn.binaryType=this.binaryType,this.conn.timeout=this.longpollerTimeout,this.conn.onopen=()=>this.onConnOpen(),this.conn.onerror=t=>this.onConnError(t),this.conn.onmessage=t=>this.onConnMessage(t),this.conn.onclose=t=>this.onConnClose(t))}log(e,t,i){this.logger(e,t,i)}hasLogger(){return this.logger!==null}onOpen(e){let t=this.makeRef();return this.stateChangeCallbacks.open.push([t,e]),t}onClose(e){let t=this.makeRef();return this.stateChangeCallbacks.close.push([t,e]),t}onError(e){let t=this.makeRef();return this.stateChangeCallbacks.error.push([t,e]),t}onMessage(e){let t=this.makeRef();return this.stateChangeCallbacks.message.push([t,e]),t}onConnOpen(){this.hasLogger()&&this.log("transport",`connected to ${this.endPointURL()}`),this.closeWasClean=!1,this.establishedConnections++,this.flushSendBuffer(),this.reconnectTimer.reset(),this.resetHeartbeat(),this.stateChangeCallbacks.open.forEach(([,e])=>e())}heartbeatTimeout(){this.pendingHeartbeatRef&&(this.pendingHeartbeatRef=null,this.hasLogger()&&this.log("transport","heartbeat timeout. Attempting to re-establish connection"),this.abnormalClose("heartbeat timeout"))}resetHeartbeat(){this.conn&&this.conn.skipHeartbeat||(this.pendingHeartbeatRef=null,clearTimeout(this.heartbeatTimer),setTimeout(()=>this.sendHeartbeat(),this.heartbeatIntervalMs))}teardown(e,t,i){if(!this.conn)return e&&e();this.waitForBufferDone(()=>{this.conn&&(t?this.conn.close(t,i||""):this.conn.close()),this.waitForSocketClosed(()=>{this.conn&&(this.conn.onclose=function(){},this.conn=null),e&&e()})})}waitForBufferDone(e,t=1){if(t===5||!this.conn||!this.conn.bufferedAmount){e();return}setTimeout(()=>{this.waitForBufferDone(e,t+1)},150*t)}waitForSocketClosed(e,t=1){if(t===5||!this.conn||this.conn.readyState===p.closed){e();return}setTimeout(()=>{this.waitForSocketClosed(e,t+1)},150*t)}onConnClose(e){this.hasLogger()&&this.log("transport","close",e),this.triggerChanError(),clearTimeout(this.heartbeatTimer),this.closeWasClean||this.reconnectTimer.scheduleTimeout(),this.stateChangeCallbacks.close.forEach(([,t])=>t(e))}onConnError(e){this.hasLogger()&&this.log("transport",e);let t=this.transport,i=this.establishedConnections;this.stateChangeCallbacks.error.forEach(([,s])=>{s(e,t,i)}),(t===this.transport||i>0)&&this.triggerChanError()}triggerChanError(){this.channels.forEach(e=>{e.isErrored()||e.isLeaving()||e.isClosed()||e.trigger(f.error)})}connectionState(){switch(this.conn&&this.conn.readyState){case p.connecting:return"connecting";case p.open:return"open";case p.closing:return"closing";default:return"closed"}}isConnected(){return this.connectionState()==="open"}remove(e){this.off(e.stateChangeRefs),this.channels=this.channels.filter(t=>t.joinRef()!==e.joinRef())}off(e){for(let t in this.stateChangeCallbacks)this.stateChangeCallbacks[t]=this.stateChangeCallbacks[t].filter(([i])=>e.indexOf(i)===-1)}channel(e,t={}){let i=new A(e,t,this);return this.channels.push(i),i}push(e){if(this.hasLogger()){let{topic:t,event:i,payload:s,ref:r,join_ref:o}=e;this.log("push",`${t} ${i} (${o}, ${r})`,s)}this.isConnected()?this.encode(e,t=>this.conn.send(t)):this.sendBuffer.push(()=>this.encode(e,t=>this.conn.send(t)))}makeRef(){let e=this.ref+1;return e===this.ref?this.ref=0:this.ref=e,this.ref.toString()}sendHeartbeat(){this.pendingHeartbeatRef&&!this.isConnected()||(this.pendingHeartbeatRef=this.makeRef(),this.push({topic:"phoenix",event:"heartbeat",payload:{},ref:this.pendingHeartbeatRef}),this.heartbeatTimer=setTimeout(()=>this.heartbeatTimeout(),this.heartbeatIntervalMs))}abnormalClose(e){this.closeWasClean=!1,this.isConnected()&&this.conn.close(O,e)}flushSendBuffer(){this.isConnected()&&this.sendBuffer.length>0&&(this.sendBuffer.forEach(e=>e()),this.sendBuffer=[])}onConnMessage(e){this.decode(e.data,t=>{let{topic:i,event:s,payload:r,ref:o,join_ref:n}=t;o&&o===this.pendingHeartbeatRef&&(clearTimeout(this.heartbeatTimer),this.pendingHeartbeatRef=null,setTimeout(()=>this.sendHeartbeat(),this.heartbeatIntervalMs)),this.hasLogger()&&this.log("receive",`${r.status||""} ${i} ${s} ${o&&"("+o+")"||""}`,r);for(let h=0;h<this.channels.length;h++){let l=this.channels[h];!l.isMember(i,s,r,n)||l.trigger(s,r,o,n)}for(let h=0;h<this.stateChangeCallbacks.message.length;h++){let[,l]=this.stateChangeCallbacks.message[h];l(t)}})}leaveOpenTopic(e){let t=this.channels.find(i=>i.topic===e&&(i.isJoined()||i.isJoining()));t&&(this.hasLogger()&&this.log("transport",`leaving duplicate topic "${e}"`),t.leave())}};export{A as Channel,y as LongPoll,g as Presence,b as Serializer,k as Socket};
//# sourceMappingURL=phoenix.js.map
