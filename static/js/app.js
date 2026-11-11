const API='/api/v1';
const FISH=['sazan','oq','buxarski','ilonbosh','amur'];
const ITEMS=[['sazan','Sazan','kg',0.5],['oq','Oq baliq','kg',0.5],['buxarski','Buxarski','kg',0.5],['ilonbosh','Ilonbosh','kg',0.5],['amur','Amur','kg',0.5],['non','Non','dona',1],['sous','Sous','dona',1],['fanta','Fanta','dona',1],['cola','Cola','dona',1],['tabaka','Tabaka','dona',1]];
const ROOMS=7;
const DEF={prices:{sazan:80000,oq:90000,buxarski:100000,ilonbosh:110000,amur:95000,non:3000,sous:5000,fanta:12000,cola:12000,tabaka:45000},tables:{},tickets:[],sales:[],seq:1,service:10,stock:{}};
let S=norm(JSON.parse(JSON.stringify(DEF))),rev=0,cur=null,draft={},pick=false,mutating=false,fishCat='sazan',pendFish=null,draftFish=[],curFish=[],fishDirty=false;
const f=n=>Math.round(n).toLocaleString('ru-RU');
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const kg=n=>(Math.round(n*100)/100).toString();
const r2=n=>Math.round(n*100)/100;
const FISH_SET=new Set(FISH);
function normFish(x){return {key:x.key,kg:r2(+x.kg||0),onion:x.onion==='sovusli'?'sovusli':'sovussiz',cut:x.cut==='kusok'?'kusok':'butun'}}
function fishFromItems(items){const src=items||{};const det=((src._fish)||[]).filter(x=>x&&FISH_SET.has(x.key)&&(+x.kg>0)).map(normFish);const covered={};det.forEach(d=>covered[d.key]=r2((covered[d.key]||0)+d.kg));const out=det.slice();FISH.forEach(k=>{const qty=r2(src[k]||0);const rem=r2(qty-(covered[k]||0));if(rem>0.001)out.push({key:k,kg:rem,onion:'sovussiz',cut:'butun',legacy:true})});return out}
function fishQtyMap(list){const m={};(list||[]).forEach(d=>{if(d&&d.kg>0)m[d.key]=r2((m[d.key]||0)+d.kg)});return m}
function buildItems(base,draftItems,fish){const items={...(base||{})};delete items._fish;ITEMS.forEach(([k])=>{if(FISH_SET.has(k))return;const v=draftItems[k]||0;if(v!==0){const nv=r2((items[k]||0)+v);if(nv>0)items[k]=nv;else delete items[k]}});const fq=fishQtyMap(fish);FISH.forEach(k=>{if(fq[k]>0)items[k]=fq[k];else delete items[k]});if(fish&&fish.length)items._fish=fish.map(d=>({key:d.key,kg:d.kg,onion:d.onion,cut:d.cut}));return items}
const _p=location.pathname.replace(/\//g,'');
const LOCK=['admin','waiter','cook'].includes(_p)?_p:(_p===''?'admin':null);
const route=()=>LOCK||(['admin','waiter','cook'].includes(location.hash.slice(1))?location.hash.slice(1):'waiter');
const money=it=>ITEMS.reduce((s,[k])=>s+(it[k]||0)*S.prices[k],0);
const svc=()=>S.service==null?10:S.service;
const isS=k=>String(k)[0]==='S';
const lblx=(k,link)=>isS(k)?'Saboy '+String(k).slice(1)+(link?' · Hona '+link:''):'Hona '+k;
const lbl=k=>lblx(k,(S.tables[k]||{}).linked_table||((S.sales.find(s=>s.table===k)||{}).linked_table));
const pctFor=k=>isS(k)?0:svc();
const fee=(s,k)=>Math.round(s*pctFor(k)/100);
const grand=(it,k)=>money(it)+fee(money(it),k);
const hm=t=>new Date(t).toLocaleTimeString('uz',{hour:'2-digit',minute:'2-digit'});
function go(r){location.hash=r;cur=null;draft={};draftFish=[];curFish=[];fishDirty=false;render()}
window.addEventListener('hashchange',render);

function render(){setTimeout(checkRing,0);
  const r=route();
  document.getElementById('nav').innerHTML=LOCK?`<div style="font-weight:700;color:var(--pri)">${{waiter:'Ofitsiant sahifasi',cook:'Oshpaz sahifasi',admin:'Admin sahifasi'}[LOCK]}</div>`:[['waiter','Ofitsiant'],['cook','Oshpaz'],['admin','Admin']]
    .map(([k,t])=>`<button class="${r===k?'on':''}" onclick="go('${k}')">${t}</button>`).join('')
    +`<a href="/logout/" style="align-self:center;padding:8px 12px;border:1px solid var(--line);border-radius:10px;background:var(--bg);color:var(--tx);font-weight:600;text-decoration:none;font-size:13px">Chiqish</a>`;
  document.getElementById('app').className=r==='admin'?'wide':'';document.getElementById('app').innerHTML=r==='admin'?admin():r==='cook'?cook():waiter();
}

/* ---------- OFITSIANT ---------- */
function waiter(){return soundBar()+alerts()+waiterMain()}
function alerts(){return S.tickets.filter(t=>t.done&&!t.seen).map(t=>`<div class="card" style="border-color:var(--ok);background:color-mix(in srgb,var(--ok) 15%,var(--card));margin-bottom:10px;display:flex;align-items:center;gap:10px;justify-content:space-between"><div><b>🔥 ${lbl(t.table)}: baliq pishdi!</b><br><small>${ITEMS.filter(([k])=>t.items[k]).map(([k,n])=>n+' '+kg(t.items[k])+' kg').join(', ')} · ${hm(t.doneAt||t.time)}</small></div><button class="btn ok" onclick="ack(${t.id})">Olib bordim</button></div>`).join('')}
function ack(id){return runMutation(()=>api(`/tickets/${id}/seen/`,{method:'POST'}))}
function waiterMain(){
  if(!cur){
    let h='<div style="display:flex;gap:10px;margin-bottom:14px"><button class="btn" style="flex:1" onclick="askSaboyRoom()">🥡 SABOY (olib ketadi)</button></div><h2 style="margin-top:0">🍽 HONA (hona raqamini tanlang)</h2><div class="grid">';
    for(let i=1;i<=ROOMS;i++){
      const t=S.tables[i];
      h+=`<button class="card tbl ${t?'busy':''}" onclick="openT(${i})"><strong>Hona ${i}</strong>${t?'Band · '+f(money(t.items))+' soʻm':'<span style="color:var(--ok)">Boʻsh</span>'}</button>`;
    }
    Object.keys(S.tables).filter(k=>/^\d+$/.test(k)&&+k>ROOMS).sort((a,b)=>+a-+b).forEach(k=>{
      const t=S.tables[k];
      h+=`<button class="card tbl ${t?'busy':''}" onclick="openT('${k}')"><strong>Hona ${k}</strong>${t?'Band · '+f(money(t.items))+' soʻm':'<span style="color:var(--ok)">Boʻsh</span>'}</button>`;
    });
    h+='</div>';
    const saboys=Object.keys(S.tables).filter(isS).sort();
    if(saboys.length){
      h+='<h2 style="margin-top:18px">🥡 SABOY</h2><div class="grid">';
      saboys.forEach(k=>{const t=S.tables[k];h+=`<button class="card tbl ${t?'busy':''}" onclick="openT('${k}')"><strong>${lbl(k)}</strong>${t?'Band · '+f(money(t.items))+' soʻm':'<span style="color:var(--ok)">Boʻsh</span>'}</button>`});
      h+='</div>';
    }
    return h;
  }
  return orderEditor();
}
function orderEditor(){
  const t=S.tables[cur]||{items:{}};
  const fishAll=curFish.concat(draftFish);
  const all=buildItems(t.items,draft,fishAll);
  const sub=money(all),feeAmt=fee(sub,cur),total=sub+feeAmt;
  const newAmt=money(draft)+draftFish.reduce((s,x)=>s+x.kg*(S.prices[x.key]||0),0);
  const canSend=(Object.values(draft).some(v=>v!==0)||draftFish.length>0||fishDirty)&&!mutating;
  const canClose=money(all)>0&&!mutating;
  let h=`<div class="card"><div style="display:flex;justify-content:space-between;align-items:center"><h2 style="margin:0">${lbl(cur)}</h2><button class="btn ghost" onclick="back()">← Orqaga</button></div>`;
  if(isS(cur)){
    h+=`<div style="margin-bottom:15px"><label style="font-weight:bold">📍 Manzil:</label><input type="text" value="${esc(t.address||'')}" onchange="saveSaboAddress('${cur}',this.value)" style="width:100%;padding:8px;margin-top:5px;border:1px solid var(--mut);border-radius:5px"></div>`;
  }
  h+=`<div style="padding:8px 0"><button class="btn ghost" style="width:100%" onclick="pick=!pick;render()">🐟 Baliq qoʻshish ${pick?'▲':'▼'}</button>${pick?fishPicker():''}</div>`;
  if(fishAll.length){
    h+='<div style="margin:4px 0 10px"><b>Buyurtmadagi baliqlar</b>';
    fishAll.forEach((d,i)=>{
      const isNew=i>=curFish.length;
      const label=`${ITEMS.find(x=>x[0]===d.key)?.[1]||d.key} — ${kg(d.kg)} kg · ${d.onion==='sovusli'?'🧅 Sovusli':'Sovussiz'} · ${d.cut==='kusok'?'Kusok':'Butun'}${isNew?' · yangi':''}`;
      h+=`<div class="row"><div class="n">${label}</div><div class="q">${isNew?`<button class="btn bad" style="padding:4px 10px" onclick="delDraftFish(${i-curFish.length})">✕</button>`:`<button class="btn ghost" style="padding:4px 10px" onclick="editFish(${i})">✎</button><button class="btn bad" style="padding:4px 10px" onclick="delFish(${i})">✕</button>`}</div></div>`;
    });
    h+='</div>';
  }
  ITEMS.forEach(([k,n,u,st])=>{
    if(FISH_SET.has(k))return;
    const d=draft[k]||0;if(k==='non')h+='<div style="color:var(--mut);font-size:13px;padding-top:12px">Boshqa</div>';
    const combined=(t.items[k]||0)+d;
    const del=t.items[k]?`<button class="btn bad" style="width:auto;height:auto;padding:4px 10px" onclick="delItem('${k}')">✕</button>`:'';
    h+=`<div class="row"><div class="n">${n}<small>${f(S.prices[k])} soʻm / ${u}${t.items[k]?' · buyurtmada: '+kg(t.items[k])+' '+u:''}${k==='tabaka'?' · qoldiq: '+kg((S.stock||{}).tabaka||0)+' dona':''}</small></div>
    <div class="q"><button onclick="chg('${k}',-${st})">−</button><input type="number" inputmode="decimal" min="0" step="${st}" value="${d}" onchange="setD('${k}',this.value)"><button onclick="chg('${k}',${st})">+</button>${del}</div>
    <div class="sum">${f(combined*S.prices[k])}</div></div>`;
  });
  h+=`<div style="display:flex;justify-content:space-between;color:var(--mut);padding-top:10px"><span>Taomlar</span><span>${f(sub)} soʻm</span></div><div style="display:flex;justify-content:space-between;color:var(--mut)"><span>Xizmat haqi (${pctFor(cur)}%)</span><span>${f(feeAmt)} soʻm</span></div><div class="total"><span>Jami</span><span>${f(total)} soʻm</span></div>
  <div class="acts"><button class="btn" onclick="send()" ${canSend?'':'disabled style="opacity:.5"'}>👨‍🍳 Yuborish (baliq → oshpaz)</button>
  <button class="btn ok" onclick="closeT()" ${canClose?'':'disabled style="opacity:.5"'}>🧾 Hisob va chek</button></div></div>`;
  return h;
}
function fishPicker(){
  if(pendFish)return `<div class="card" style="margin-top:8px;border-color:var(--warn)"><b>🐟 ${ITEMS.find(x=>x[0]===pendFish.key)[1]} — ${kg(pendFish.kg)} kg</b><div style="margin:8px 0;color:var(--mut);font-size:13px">Qanday tayyorlaymiz?</div><div class="grid"><button class="btn ok" onclick="confirmFish('sovusli','butun')">🧅 Sovusli · Butun</button><button class="btn" onclick="confirmFish('sovusli','kusok')">🧅 Sovusli · Kusok</button><button class="btn" onclick="confirmFish('sovussiz','butun')">Sovussiz · Butun</button><button class="btn" onclick="confirmFish('sovussiz','kusok')">Sovussiz · Kusok</button></div></div>`;
  const list=(S.fishList||[]).filter(e=>e.key===fishCat);
  let h=`<div style="margin-top:8px"><div class="grid" style="grid-template-columns:repeat(4,1fr);gap:6px">${FISH.map(k=>`<button class="btn ${fishCat===k?'':'ghost'}" style="padding:8px 4px;font-size:13px" onclick="fishCat='${k}';render()">${ITEMS.find(x=>x[0]===k)[1]}</button>`).join('')}</div>`;
  if(!list.length)h+='<div style="color:var(--mut);font-size:12px;margin-top:8px">Bu turdagi baliq hali kiritilmagan</div>';
  else h+='<div class="grid" style="margin-top:8px">'+list.map(e=>`<button class="btn" onclick="pickFish(${e.id})">${kg(e.kg)} kg<br><small>${f(S.prices[e.key]||0)} soʻm/kg</small></button>`).join('')+'</div>';
  return h+'</div>';
}
function pickFish(id){const e=(S.fishList||[]).find(x=>x.id===id);if(e){pendFish={key:e.key,kg:e.kg};render()}}
function confirmFish(onion,cut){
  if(!pendFish)return;
  const {key,kg:w}=pendFish;
  draftFish.push({key,kg:w,onion,cut});
  pendFish=null;pick=false;render();
}
function editFish(i){
  const d=curFish[i];if(!d)return;
  document.getElementById('modal').innerHTML=`<div class="modal"><div><h3>🐟 Baliqni tahrirlash</h3><div class="pr"><div><label>Ogʻirligi (kg)</label><input id="fe_kg" type="number" inputmode="decimal" step="0.1" min="0" value="${kg(d.kg)}"></div><div><label>Piyoz</label><select id="fe_onion"><option value="sovusli" ${d.onion==='sovusli'?'selected':''}>🧅 Sovusli</option><option value="sovussiz" ${d.onion!=='sovusli'?'selected':''}>Sovussiz</option></select></div><div><label>Shakli</label><select id="fe_cut"><option value="butun" ${d.cut!=='kusok'?'selected':''}>Butun</option><option value="kusok" ${d.cut==='kusok'?'selected':''}>Kusok</option></select></div></div><div class="acts" style="margin-top:12px"><button class="btn" onclick="saveFishEdit(${i})">Saqlash</button><button class="btn ghost" onclick="document.getElementById('modal').innerHTML=''">Bekor qilish</button></div></div></div>`;
}
function saveFishEdit(i){
  const kgv=parseFloat(String(document.getElementById('fe_kg').value).replace(',','.'));
  if(!kgv||kgv<=0){alert('Ogʻirlikni toʻgʻri kiriting');return}
  curFish[i]={...curFish[i],kg:r2(kgv),onion:document.getElementById('fe_onion').value,cut:document.getElementById('fe_cut').value};
  fishDirty=true;document.getElementById('modal').innerHTML='';render();
}
function delFish(i){if(!confirm('Bu baliqni buyurtmadan oʻchirasizmi?'))return;curFish.splice(i,1);fishDirty=true;render()}
function delDraftFish(i){draftFish.splice(i,1);render()}
function delItem(k){
  const t=S.tables[cur]||{items:{}};
  const qty=t.items[k]||0;
  if(!qty)return;
  if(!confirm('Buyurtmadagi bu mahsulotni o‘chirasizmi?'))return;
  draft[k]=r2((draft[k]||0)-qty);
  render();
}
function openT(i){cur=i;draft={};pick=false;fishCat='sazan';pendFish=null;draftFish=[];curFish=fishFromItems((S.tables[i]||{}).items);fishDirty=false;render()}
function chg(k,d){draft[k]=Math.max(0,Math.round(((draft[k]||0)+d)*100)/100);render()}
function setD(k,v){draft[k]=Math.max(0,parseFloat(v)||0);render()}
async function send(){
  if((!Object.values(draft).some(v=>v!==0)&&!draftFish.length&&!fishDirty)||mutating)return;
  const tb=String(cur);
  mutating=true;
  try{
    const t=S.tables[tb]||{items:{}};
    const fishAll=curFish.concat(draftFish);
    const items=buildItems(t.items,draft,fishAll);
    const empty=!money(items)&&!(items._fish&&items._fish.length);
    if(empty){
      if(S.tables[tb])await api(`/table-states/${encodeURIComponent(tb)}/`,{method:'DELETE'});
    }else{
      const body={items,address:t.address||'',saboy:!!t.saboy,linked_table:t.linked_table||''};
      if(S.tables[tb])await api(`/table-states/${encodeURIComponent(tb)}/`,{method:'PATCH',body:JSON.stringify(body)});
      else await api('/table-states/',{method:'POST',body:JSON.stringify({table_key:tb,...body})});
    }
    if(draftFish.length){
      const fi=fishQtyMap(draftFish);
      fi._fish=draftFish.map(x=>({key:x.key,kg:x.kg,onion:x.onion,cut:x.cut}));
      await api('/tickets/',{method:'POST',body:JSON.stringify({table:tb,items:fi})});
    }
    draft={};draftFish=[];fishDirty=false;curFish=fishFromItems(items);
    await sync();
    return true;
  }catch(e){showError(e);return false}finally{mutating=false}
}
async function closeT(){
  if(mutating)return;
  const tb=String(cur);
  const t=S.tables[tb]||{items:{}};
  const items=buildItems(t.items,draft,curFish.concat(draftFish));
  if(!money(items))return;
  const sub=money(items),pct=pctFor(tb),feeAmt=fee(sub,tb);
  const sale={
    table:tb,items,sub,pct,fee:feeAmt,total:sub+feeAmt,
    prices:{...S.prices},address:t.address||'',linked_table:t.linked_table||'',clear_table:true
  };
  mutating=true;
  try{
    const data=await api('/sales/',{method:'POST',body:JSON.stringify(sale)});
    cur=null;draft={};draftFish=[];curFish=[];fishDirty=false;
    await sync();
    if(data&&data.table)receipt(data);
  }catch(e){showError(e)}finally{mutating=false}
}
function receipt(s){
  const lines=ITEMS.filter(([k])=>s.items[k]).map(([k,n,u])=>`<div class="l"><span>${n} ${kg(s.items[k])} ${u}</span><span>${f(s.items[k]*s.prices[k])}</span></div>`).join('');
  const address=s.address||S.tables[s.table]?.address||'';
  document.getElementById('modal').innerHTML=`<div class="modal"><div><div class="rc"><div style="text-align:center"><b>FAYZ BALIQXONASI</b><br>Chek №${s.id}</div><hr>
  <div>${lblx(s.table,s.linked_table||(S.tables[s.table]||{}).linked_table)}${address?`<br>📍 ${esc(address)}`:''}<br>${new Date(s.time).toLocaleString('uz')}</div><hr>${lines}<hr>
  <div class="l"><span>Taomlar</span><span>${f(s.sub??s.total)}</span></div>${s.pct>0?`<div class="l"><span>Xizmat (${s.pct}%)</span><span>${f(s.fee||0)}</span></div>`:''}<div class="l"><b>JAMI:</b><b>${f(s.total)} soʻm</b></div><hr><div style="text-align:center">Rahmat! Yana kutamiz 🐟</div></div>
  <div class="acts" style="margin-top:10px"><button class="btn" onclick="window.print();document.getElementById('modal').innerHTML=''">🖨 Chekni chiqar</button><button class="btn ghost" onclick="document.getElementById('modal').innerHTML=''">Yopish</button></div></div></div>`;
}

/* ---------- OSHPAZ ---------- */
function ticketLines(t){
  const det=(t.items&&t.items._fish)||[];
  if(det.length)return det.map(x=>`<li><b>${ITEMS.find(i=>i[0]===x.key)?.[1]||x.key}</b> — ${kg(x.kg)} kg · ${x.onion==='sovusli'?'🧅 Sovusli':'Sovussiz'} · ${x.cut==='kusok'?'Kusok':'Butun'}</li>`).join('');
  return ITEMS.filter(([k])=>t.items[k]).map(([k,n,u])=>`<li><b>${n}</b> — ${kg(t.items[k])} ${u}</li>`).join('');
}
function cook(){
  if(cur&&isS(cur))return soundBar()+orderEditor();
  const open=S.tickets.filter(t=>!t.done).reverse(),done=S.tickets.filter(t=>t.done).slice(-4).reverse();
  const tk=t=>`<div class="card tk ${t.done?'done':!t.acc?'new':''}" style="margin-bottom:10px"><h3>${lbl(t.table)} <small style="color:var(--mut);font-weight:400">· ${hm(t.time)}</small></h3>${isS(t.table)?`<div style="background:var(--warn);color:var(--bg);padding:10px;border-radius:5px;margin:10px 0"><label>📍 Manzil:</label><input type="text" id="address_${t.table}" value="${esc(S.tables[t.table]?.address||'')}" onchange="saveSaboAddress('${t.table}',this.value)" style="width:100%;padding:6px;margin-top:4px;border:none;border-radius:3px"></div>`:''}<ul style="margin:0 0 10px;padding-left:20px">${ticketLines(t)}</ul>${t.done?'':`${t.acc?`<button class="btn ok" style="width:100%;font-size:18px;padding:16px" onclick="ready(${t.id})">🔥 Baliq pishdi</button>`:`<button class="btn" style="width:100%;font-size:18px;padding:16px" onclick="accept(${t.id})">🔔 Qabul qildim</button>`}`}</div>`;
  const tkDone=t=>`<div class="card tk done" style="margin-bottom:10px"><h3>${lbl(t.table)} <small style="color:var(--mut);font-weight:400">· ${hm(t.time)}</small></h3>${isS(t.table)?`<div style="background:var(--warn);color:var(--bg);padding:10px;border-radius:5px;margin:10px 0"><label>📍 Manzil:</label><input type="text" id="address_${t.table}" value="${esc(S.tables[t.table]?.address||'')}" onchange="saveSaboAddress('${t.table}',this.value)" style="width:100%;padding:6px;margin-top:4px;border:none;border-radius:3px"></div>`:''}<ul style="margin:0 0 10px;padding-left:20px">${ticketLines(t)}</ul></div>`;
  return soundBar()+`<button class="btn" style="width:100%;margin-bottom:15px" onclick="newSaboy()">🥡 SABOY (olib ketadi)</button><h2 style="margin-top:0">Yangi buyurtmalar (${open.length})</h2>${open.map(tk).join('')||'<div class="card" style="color:var(--mut)">Hozircha buyurtma yoʻq</div>'}
  ${done.length?'<h2>Tayyor boʻlganlar</h2>'+done.map(tkDone).join(''):''}`;
}
function ready(id){return runMutation(()=>api(`/tickets/${id}/ready/`,{method:'POST'}))}
async function saveSaboAddress(key,v){
  return runMutation(async()=>{
    if(S.tables[key])await api(`/table-states/${encodeURIComponent(key)}/`,{method:'PATCH',body:JSON.stringify({address:v})});
    else await api('/table-states/',{method:'POST',body:JSON.stringify({table_key:key,items:{},address:v,saboy:isS(key)})});
  });
}
let actx=null,ringT=null;
function tone(fq,t,d){const o=actx.createOscillator(),g=actx.createGain();o.type='square';o.frequency.value=fq;g.gain.value=.3;o.connect(g);g.connect(actx.destination);o.start(actx.currentTime+t);o.stop(actx.currentTime+t+d)}
function beep(){try{if(actx)[1000,1300].forEach((q,i)=>tone(q,i*.2,.18))}catch(e){}}
function ring(){try{if(actx)[880,1100,880,1100,880].forEach((q,i)=>tone(q,i*.25,.2))}catch(e){}}
function unlock(){try{actx=actx||new(window.AudioContext||window.webkitAudioContext)();actx.resume();ring()}catch(e){}render()}
const soundBar=()=>actx?'':'<button class="btn" style="width:100%;margin-bottom:10px;background:var(--warn)" onclick="unlock()">🔔 Ovozni yoqish (bir marta bosing)</button>';
function checkRing(){
  const need=route()==='cook'&&S.tickets.some(t=>!t.done&&!t.acc);
  if(need&&!ringT){ring();ringT=setInterval(()=>{if(route()==='cook'&&S.tickets.some(t=>!t.done&&!t.acc))ring();else checkRing()},5000)}
  if(!need&&ringT){clearInterval(ringT);ringT=null}
}
function accept(id){return runMutation(()=>api(`/tickets/${id}/accept/`,{method:'POST'}))}
async function newSaboy(linked=''){
  if(mutating)return;
  mutating=true;
  try{
    const settings=await api('/settings/');
    const next=(settings.seqS||0)+1;
    await api('/settings/',{method:'PATCH',body:JSON.stringify({seqS:next})});
    const key='S'+next;
    await api('/table-states/',{method:'POST',body:JSON.stringify({table_key:key,items:{},saboy:true,linked_table:linked||''})});
    cur=key;draft={};pick=false;fishCat='sazan';pendFish=null;draftFish=[];curFish=[];fishDirty=false;
    await sync();
  }catch(e){showError(e)}finally{mutating=false}
}
function askSaboyRoom(){
  const rooms=[];
  for(let i=1;i<=ROOMS;i++)rooms.push(String(i));
  Object.keys(S.tables).forEach(k=>{if(/^\d+$/.test(k)&&+k>ROOMS&&!rooms.includes(k))rooms.push(k)});
  rooms.sort((a,b)=>+a-+b);
  const busy=k=>S.tables[k]&&money(S.tables[k].items)>0;
  document.getElementById('modal').innerHTML=`<div class="modal"><div><h3>🥡 Qaysi hona uchun saboy?</h3><div class="grid">${rooms.map(k=>`<button class="btn ${busy(k)?'':'ghost'}" onclick="pickSaboyRoom('${k}')">Hona ${k}${busy(k)?' · band':''}</button>`).join('')}</div><div class="acts" style="margin-top:12px"><button class="btn ghost" onclick="document.getElementById('modal').innerHTML=''">Bekor qilish</button></div></div></div>`;
}
function pickSaboyRoom(k){document.getElementById('modal').innerHTML='';return newSaboy(k)}
function back(){
  const k=cur;cur=null;draft={};pick=false;fishCat='sazan';pendFish=null;draftFish=[];curFish=[];fishDirty=false;render();
  if(isS(k)&&S.tables[k]&&!money(S.tables[k].items)){
    runMutation(()=>api(`/table-states/${encodeURIComponent(k)}/`,{method:'DELETE'}));
  }
}

/* ---------- ADMIN ---------- */
let atab='home',aper='today',sdate='';
const SM=' soʻm';
function setTab(t){atab=t;render()}
function setPer(p){aper=p;render()}
function setDate(v){sdate=v||'';render()}
function dkey(t){const d=new Date(t);const p=n=>String(n).padStart(2,'0');return d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate())}
function todayKey(){return dkey(Date.now())}
function isClosedDate(k){return (S.closedDates||[]).includes(k)}
function reprint(id){const x=S.sales.find(y=>y.id===id);if(x)receipt(x)}
const pr=(x,k)=>(x.prices||S.prices)[k]||0;
const nm=k=>ITEMS.find(i=>i[0]===k)[1];
function salesTable(list){
  const fi=x=>FISH.filter(k=>x.items[k]).map(k=>nm(k)+' '+kg(x.items[k])+' kg').join(', ')||'—';
  return `<div class="card scroll"><table class="tt"><thead><tr><th>№</th><th>Vaqt</th><th>Hona</th><th>Baliq</th><th>Non</th><th>Sous</th><th>Fanta</th><th>Cola</th><th>Tabaka</th><th class="num">Xizmat</th><th class="num">Jami</th><th></th></tr></thead><tbody>${list.map(x=>`<tr><td>${x.id}</td><td>${new Date(x.time).toLocaleString('uz',{dateStyle:'short',timeStyle:'short'})}</td><td>${lblx(x.table,x.linked_table)}</td><td>${fi(x)}</td><td>${x.items.non||0}</td><td>${x.items.sous||0}</td><td>${x.items.fanta||0}</td><td>${x.items.cola||0}</td><td>${x.items.tabaka||0}</td><td class="num">${f(x.fee||0)}</td><td class="num"><b>${f(x.total)}</b></td><td><button class="btn ghost" style="padding:4px 10px;font-size:13px" onclick="reprint(${x.id})">Chek</button> <button class="btn" style="padding:4px 10px;font-size:13px" onclick="reopenSale(${x.id})">Ochish</button></td></tr>`).join('')||'<tr><td colspan="12" style="color:var(--mut)">Sotuv yoʻq</td></tr>'}</tbody></table></div>`;
}
function admin(){
  const t0=new Date().setHours(0,0,0,0),from=aper==='today'?t0:aper==='week'?t0-6*864e5:0;
  const sl=sdate?S.sales.filter(x=>dkey(x.time)===sdate):S.sales.filter(x=>x.time>=from);
  const qty=k=>sl.reduce((a,x)=>a+(x.items[k]||0),0);
  const amt=k=>sl.reduce((a,x)=>a+(x.items[k]||0)*pr(x,k),0);
  const rev=sl.reduce((a,x)=>a+x.total,0),fees=sl.reduce((a,x)=>a+(x.fee||0),0);
  const fishKg=FISH.reduce((a,k)=>a+qty(k),0),fishSum=FISH.reduce((a,k)=>a+amt(k),0);
  const OTH=['non','sous','fanta','cola','tabaka'];
  const tabs=[['home','📊 Umumiy'],['fish','🐟 Baliq hisoboti'],['weights','⚖️ Ogʻirliklar'],['other','🥤 Non va ichimlik'],['sales','🧾 Sotuvlar tarixi'],['set','⚙️ Narxlar va sozlama']];
  const pers=[['today','Bugun'],['week','Oxirgi 7 kun'],['all','Hammasi']];
  const kpi=(v,l,c)=>`<div class="card stat kpi" style="border-top-color:${c}"><b>${v}</b><span>${l}</span></div>`;
  const inp=k=>`<div><label>${nm(k)} (soʻm)</label><input type="number" min="0" value="${S.prices[k]}" onchange="setP('${k}',this.value)"></div>`;
  let b='';
  if(atab==='home'){
    const busy=Object.entries(S.tables);
    b=`<div class="grid">${kpi(f(rev)+SM,'Umumiy tushum (xizmat bilan)','var(--pri)')}${kpi(f(rev-fees)+SM,'Taomlar summasi','var(--ok)')}${kpi(f(fees)+SM,'Xizmat haqi','var(--warn)')}${kpi(sl.length,'Chiqarilgan cheklar','var(--mut)')}${kpi(kg(fishKg)+' kg','Sotilgan baliq','var(--pri)')}${kpi(busy.filter(([n])=>!isS(n)).length+' / '+ROOMS,'Hozir band honalar','var(--bad)')}</div>
    <h2>Hozir band honalar</h2><div class="card">${busy.map(([n,t])=>`<div class="row"><div class="n"><b>${lbl(n)}</b>${t.address?`<br><small style="color:var(--mut)">📍 ${esc(t.address)}</small>`:''}</div><div class="sum">${f(grand(t.items,n))}${SM}</div></div>`).join('')||'<span style="color:var(--mut)">Hamma hona boʻsh</span>'}</div>
    <h2>Oxirgi cheklar</h2>${salesTable(sl.slice(-5).reverse())}`;
  }else if(atab==='fish'){
    b=`<div class="card scroll"><table class="tt"><thead><tr><th>Baliq turi</th><th class="num">Narxi (1 kg)</th><th class="num">Sotilgan</th><th class="num">Summa</th><th>Ulushi</th></tr></thead><tbody>${FISH.map(k=>{const p=fishKg?qty(k)/fishKg*100:0;return `<tr><td><b>${nm(k)}</b></td><td class="num">${f(S.prices[k])}</td><td class="num">${kg(qty(k))} kg</td><td class="num">${f(amt(k))}</td><td style="min-width:110px"><div class="bar"><i style="width:${p}%"></i></div><small>${Math.round(p)}%</small></td></tr>`}).join('')}</tbody><tfoot><tr><td colspan="2">Jami baliq</td><td class="num">${kg(fishKg)} kg</td><td class="num">${f(fishSum)}</td><td></td></tr></tfoot></table></div>`;
  }else if(atab==='weights'){
    b=`<h2 style="margin-top:0">⚖️ Baliq ogʻirliklari (kg)</h2><div class="card"><p style="color:var(--mut);font-size:13px;margin-top:0">Ofitsiant qidirishi uchun mavjud baliqlar roʻyxati. Har bir qator — bitta baliqning ogʻirligi.</p>
    <div class="pr" style="margin-bottom:12px"><div><label>Baliq turi</label><select onchange="fwKey=this.value">${FISH.map(k=>`<option value="${k}" ${fwKey===k?'selected':''}>${nm(k)}</option>`).join('')}</select></div>
    <div><label>Ogʻirligi (kg)</label><input type="number" inputmode="decimal" step="0.1" min="0" placeholder="1.3" value="${fwKg}" onchange="fwKg=this.value"></div>
    <div style="align-self:end"><button class="btn" onclick="addFishWeight()">➕ Qoʻshish</button></div></div>
    ${(S.fishList||[]).map(e=>`<div class="row"><div class="n"><b>${nm(e.key)}</b><small>${kg(e.kg)} kg</small></div><button class="btn bad" style="padding:4px 12px" onclick="delFishWeight(${e.id})">🗑</button></div>`).join('')||'<span style="color:var(--mut)">Hali baliq kiritilmagan</span>'}</div>`;
  }else if(atab==='other'){
    b=`<div class="card scroll"><table class="tt"><thead><tr><th>Mahsulot</th><th class="num">Narxi</th><th class="num">Sotilgan</th><th class="num">Summa</th></tr></thead><tbody>${OTH.map(k=>`<tr><td><b>${nm(k)}</b></td><td class="num">${f(S.prices[k])}</td><td class="num">${kg(qty(k))} dona</td><td class="num">${f(amt(k))}</td></tr>`).join('')}</tbody><tfoot><tr><td colspan="3">Jami</td><td class="num">${f(OTH.reduce((a,k)=>a+amt(k),0))}</td></tr></tfoot></table></div>`;
  }else if(atab==='sales'){
    const sel=sdate||todayKey();
    const closed=isClosedDate(sel);
    b=`<div class="card" style="margin-bottom:10px;display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap"><div><b>${sel}</b>${closed?' · <span style="color:var(--ok)">Yopilgan</span>':''}<br><small style="color:var(--mut)">Oxirgi ${S.retentionDays||10} kun saqlanadi</small></div><button class="btn" onclick="closeDay()" ${closed?'disabled style="opacity:.5"':''}>🔒 Bugungi kunni yopish</button></div>`+salesTable(sl.slice().reverse());
  }else{
    b=`<h2 style="margin-top:0">🐟 Baliq narxlari (1 kg)</h2><div class="pr">${FISH.map(inp).join('')}</div><h2>🥤 Non va ichimliklar (1 dona)</h2><div class="pr">${OTH.map(inp).join('')}</div><h2>📦 Qoldiq</h2><div class="card"><p style="color:var(--mut);font-size:13px;margin-top:0">Tabaka — nechta dona qoldigʻi bor. Sotilganda avtomatik kamayadi.</p><div class="pr"><div><label>Tabaka qoldigʻi (dona)</label><input type="number" min="0" step="1" value="${(S.stock||{}).tabaka||0}" onchange="setStock('tabaka',this.value)"></div></div></div><h2>Xizmat haqi</h2><div class="pr"><div><label>Foiz (%)</label><input type="number" min="0" max="100" value="${svc()}" onchange="setSvc(this.value)"></div></div><h2>Xavfli boʻlim</h2><button class="btn bad" onclick="resetAll()">Barcha sotuvlarni tozalash</button><div style="height:10px"></div><button class="btn bad" onclick="clearSales()">Faqat barcha cheklarni o‘chirish</button>`;
  }
  return `<div class="adm"><aside class="side">${tabs.map(([k,t])=>`<button class="${atab===k?'on':''}" onclick="setTab('${k}')">${t}</button>`).join('')}</aside><section>${atab==='set'?'':`<div class="per">${pers.map(([k,t])=>`<button class="${aper===k?'on':''}" onclick="setPer('${k}')">${t}</button>`).join('')}<input type="date" value="${sdate}" onchange="setDate(this.value)" style="margin-left:auto;padding:6px 8px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--tx)"></div>`}${b}</section></div>`;
}
let fwKey='sazan',fwKg='';
function saveFishList(list){return runMutation(()=>api('/settings/',{method:'PATCH',body:JSON.stringify({fishList:list})}))}
function addFishWeight(){
  const kgv=parseFloat(String(fwKg).replace(',','.'));
  if(!kgv||kgv<=0){alert('Ogʻirlikni kiriting');return}
  fwKg='';
  return saveFishList([...(S.fishList||[]),{id:Date.now(),key:fwKey,kg:kgv}]);
}
function delFishWeight(id){return saveFishList((S.fishList||[]).filter(e=>e.id!==id))}
function setSvc(v){const n=Math.min(100,Math.max(0,parseFloat(v)||0));return runMutation(()=>api('/settings/',{method:'PATCH',body:JSON.stringify({service:n})}))}
function setP(k,v){const n=Math.max(0,parseFloat(v)||0);return runMutation(()=>api('/settings/',{method:'PATCH',body:JSON.stringify({prices:{[k]:n}})}))}
function setStock(k,v){const n=Math.max(0,parseFloat(v)||0);return runMutation(()=>api('/settings/',{method:'PATCH',body:JSON.stringify({stock:{[k]:n}})}))}
function resetAll(){
  if(!confirm('Hamma sotuvlar va buyurtmalar oʻchiriladi. Davom etasizmi?'))return;
  return runMutation(async()=>{await api('/settings/reset/',{method:'POST'});cur=null;draft={};draftFish=[];curFish=[];fishDirty=false});
}
function reopenSale(id){
  if(!confirm('Bu chek qayta ochilsinmi? Stol holati tiklanadi.'))return;
  return runMutation(()=>api(`/sales/${id}/reopen/`,{method:'POST'}));
}
function clearSales(){
  if(!confirm('Barcha cheklar oʻchiriladi. Davom etasizmi?'))return;
  return runMutation(()=>api('/sales/clear/',{method:'DELETE'}));
}
function closeDay(){
  if(!confirm('Bugungi kunlik yopilsinmi?'))return;
  return runMutation(async()=>{await api('/settings/close-day/',{method:'POST'});sdate=todayKey()});
}

/* ---------- SERVER BILAN ALOQA ---------- */
function norm(x){x=x||{};x.prices={...DEF.prices,...(x.prices||{})};x.tables=x.tables||{};x.tickets=x.tickets||[];x.sales=x.sales||[];x.seq=x.seq||1;if(x.service==null)x.service=10;x.fishList=x.fishList||[];x.stock=x.stock||{};x.closedDates=x.closedDates||[];x.retentionDays=x.retentionDays||10;for(const k in x.tables){const t=x.tables[k];if(t)t.items=t.items||{}}x.tickets.forEach(t=>{if(t)t.items=t.items||{}});x.sales.forEach(s=>{if(s){s.items=s.items||{};s.prices=s.prices||{}}});return x}
function apply(d){S=norm(d.state);rev=(d.rev!=null?d.rev:(d.state&&d.state._rev)||0)}
function status(ok){const e=document.getElementById('st');if(e){e.textContent=ok?'\u25cf onlayn':'\u25cf aloqa yoʻq';e.style.color=ok?'var(--ok)':'var(--bad)'}}
function errText(d){
  if(!d)return 'HTTP xato';
  if(typeof d==='string')return d;
  if(d.error)return d.error;
  if(d.detail)return d.detail;
  const first=Object.entries(d)[0];
  return first?first[0]+': '+[].concat(first[1]).join(', '):'HTTP xato';
}
async function api(path,opts={}){
  let r;
  try{
    r=await fetch(API+path,{...opts,headers:{'Content-Type':'application/json',...(opts.headers||{})}});
  }catch(_){
    status(false);
    throw new Error('Server bilan aloqa yoʻq. Qayta urinib koʻring.');
  }
  let d={};
  try{d=await r.json()}catch(_){}
  if(!r.ok)throw new Error(errText(d));
  status(true);
  return d;
}
function showError(e){status(false);console.error(e);alert('Saqlashda xatolik: '+(e&&e.message?e.message:e))}
async function sync(){
  const d=await api('/state/');
  apply(d);
  status(true);
  render();
  return true;
}
async function reload(){
  try{await sync();return true}catch(_){status(false);return false}
}
async function runMutation(fn){
  if(mutating)return false;
  mutating=true;
  try{await fn();await sync();return true}
  catch(e){showError(e);return false}
  finally{mutating=false}
}
function boot(){
  const n=x=>x.tickets.filter(t=>t.done).length;
  // Boshlang'ich yuklash
  (async()=>{
    try{await sync()}catch(e){status(false)}
  })();
  // Har 2 sekundda holatni yangilab turamiz
  setInterval(async()=>{
    if(mutating)return;   // saqlash ketayotganda ustidan yozmaslik uchun
    try{
      const d=await api('/state/');
      status(true);
      if(mutating||d.rev===rev||d.rev<rev)return;
      const o=S;
      apply(d);
      if(n(S)>n(o)&&route()!=='cook')beep();
      const ae=document.activeElement;
      if(!(ae&&/^(INPUT|TEXTAREA|SELECT)$/.test(ae.tagName)))render();
    }catch(e){status(false)}
  },2000);
}
render();boot();
