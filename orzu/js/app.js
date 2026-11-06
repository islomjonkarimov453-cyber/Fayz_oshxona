const FISH=['sazan','oq','buxarski','ilonbosh'];
const ITEMS=[['sazan','Sazan','kg',0.5],['oq','Oq baliq','kg',0.5],['buxarski','Buxarski','kg',0.5],['ilonbosh','Ilonbosh','kg',0.5],['non','Non','dona',1],['sous','Sous','dona',1],['fanta','Fanta','dona',1],['cola','Cola','dona',1]];
const ROOMS=7;
const DEF={prices:{sazan:80000,oq:90000,buxarski:100000,ilonbosh:110000,non:3000,sous:5000,fanta:12000,cola:12000},tables:{},tickets:[],sales:[],seq:1,service:10};
let S=norm(JSON.parse(JSON.stringify(DEF))),rev=0,cur=null,draft={},pick=false;
const f=n=>Math.round(n).toLocaleString('ru-RU');
const kg=n=>(Math.round(n*100)/100).toString();
const LOCK=['admin','waiter','cook'].find(r=>location.pathname.replace(/\//g,'')===r);
const route=()=>LOCK||(['admin','waiter','cook'].includes(location.hash.slice(1))?location.hash.slice(1):'waiter');
const money=it=>ITEMS.reduce((s,[k])=>s+(it[k]||0)*S.prices[k],0);
const svc=()=>S.service==null?10:S.service;
const isS=k=>String(k)[0]==='S';
const lbl=k=>isS(k)?'Saboy '+String(k).slice(1):'Hona '+k;
const pctFor=k=>isS(k)?0:svc();
const fee=(s,k)=>Math.round(s*pctFor(k)/100);
const grand=(it,k)=>money(it)+fee(money(it),k);
const hm=t=>new Date(t).toLocaleTimeString('uz',{hour:'2-digit',minute:'2-digit'});
function go(r){location.hash=r;cur=null;draft={};render()}
window.addEventListener('hashchange',render);

function render(){setTimeout(checkRing,0);
  const r=route();
  document.getElementById('nav').innerHTML=LOCK?`<div style="font-weight:700;color:var(--pri)">${{waiter:'Ofitsiant sahifasi',cook:'Oshpaz sahifasi',admin:'Admin sahifasi'}[LOCK]}</div>`:[['waiter','Ofitsiant'],['cook','Oshpaz'],['admin','Admin']]
    .map(([k,t])=>`<button class="${r===k?'on':''}" onclick="go('${k}')">${t}</button>`).join('');
  document.getElementById('app').className=r==='admin'?'wide':'';document.getElementById('app').innerHTML=r==='admin'?admin():r==='cook'?cook():waiter();
}

/* ---------- OFITSIANT ---------- */
function waiter(){return soundBar()+alerts()+waiterMain()}
function alerts(){return S.tickets.filter(t=>t.done&&!t.seen).map(t=>`<div class="card" style="border-color:var(--ok);background:color-mix(in srgb,var(--ok) 15%,var(--card));margin-bottom:10px;display:flex;align-items:center;gap:10px;justify-content:space-between"><div><b>🔥 ${lbl(t.table)}: baliq pishdi!</b><br><small>${ITEMS.filter(([k])=>t.items[k]).map(([k,n])=>n+' '+kg(t.items[k])+' kg').join(', ')} · ${hm(t.doneAt)}</small></div><button class="btn ok" onclick="ack(${t.id})">Olib bordim</button></div>`).join('')}
function ack(id){mutate(()=>{const t=S.tickets.find(x=>x.id===id);if(t)t.seen=true})}
function waiterMain(){
  if(!cur){
    const sab=Object.keys(S.tables).filter(isS);
    let h='<h2 style="margin-top:0">Buyurtma qayerga? Saboymi yoki hona?</h2><button class="btn" style="width:100%;font-size:18px;padding:18px" onclick="newSaboy()">🥡 SABOY (olib ketadi)</button>';
    if(sab.length)h+='<h2>Ochiq saboylar</h2><div class="grid">'+sab.map(k=>`<button class="card tbl busy" onclick="openT('${k}')"><strong>${lbl(k)}</strong>${f(money(S.tables[k].items))} soʻm</button>`).join('')+'</div>';
    h+='<h2>🍽 HONA (hona raqamini tanlang)</h2><div class="grid">';
    for(let i=1;i<=ROOMS;i++){
      const t=S.tables[i];
      h+=`<button class="card tbl ${t?'busy':''}" onclick="openT(${i})"><strong>Hona ${i}</strong>${t?'Band · '+f(money(t.items))+' soʻm':'<span style="color:var(--ok)">Boʻsh</span>'}</button>`;
    }
    return h+'</div>';
  }
  const t=S.tables[cur]||{items:{}};
  const all={};ITEMS.forEach(([k])=>all[k]=(t.items[k]||0)+(draft[k]||0));
  let h=`<div class="card"><div style="display:flex;justify-content:space-between;align-items:center"><h2 style="margin:0">${lbl(cur)}</h2><button class="btn ghost" onclick="back()">← Orqaga</button></div>`;
  ITEMS.forEach(([k,n,u,st])=>{
    const d=draft[k]||0;if(k==='sazan')h+=`<div style="padding:8px 0"><button class="btn ghost" style="width:100%" onclick="pick=!pick;render()">🐟 Baliq qoʻshish ${pick?'▲':'▼'}</button>${pick?`<div class="grid" style="margin-top:8px">${FISH.map(q=>`<button class="btn" onclick="addFish('${q}')">${ITEMS.find(x=>x[0]===q)[1]}<br><small>${f(S.prices[q])} soʻm/kg</small></button>`).join('')}</div>`:''}</div>`;if(FISH.includes(k)&&!draft[k]&&!t.items[k])return;if(k==='non')h+='<div style="color:var(--mut);font-size:13px;padding-top:12px">Boshqa</div>';
    h+=`<div class="row"><div class="n">${n}<small>${f(S.prices[k])} soʻm / ${u}${t.items[k]?' · buyurtmada: '+kg(t.items[k])+' '+u:''}</small></div>
    <div class="q"><button onclick="chg('${k}',-${st})">−</button><input type="number" inputmode="decimal" min="0" step="${st}" value="${d}" onchange="setD('${k}',this.value)"><button onclick="chg('${k}',${st})">+</button></div>
    <div class="sum">${f(all[k]*S.prices[k])}</div></div>`;
  });
  const newAmt=money(draft);
  h+=`<div style="display:flex;justify-content:space-between;color:var(--mut);padding-top:10px"><span>Taomlar</span><span>${f(money(all))} soʻm</span></div><div style="display:flex;justify-content:space-between;color:var(--mut)"><span>Xizmat haqi (${pctFor(cur)}%)</span><span>${f(fee(money(all),cur))} soʻm</span></div><div class="total"><span>Jami</span><span>${f(grand(all,cur))} soʻm</span></div>
  <div class="acts"><button class="btn" onclick="send()" ${newAmt?'':'disabled style="opacity:.5"'}>👨‍🍳 Yuborish (baliq → oshpaz)</button>
  <button class="btn ok" onclick="closeT()" ${money(t.items)||newAmt?'':'disabled style="opacity:.5"'}>🧾 Hisob va chek</button></div></div>`;
  return h;
}
function addFish(k){draft[k]=(draft[k]||0)+0.5;pick=false;render()}
function openT(i){cur=i;draft={};pick=false;render()}
function chg(k,d){draft[k]=Math.max(0,Math.round(((draft[k]||0)+d)*100)/100);render()}
function setD(k,v){draft[k]=Math.max(0,parseFloat(v)||0);render()}
async function send(){
  if(!money(draft))return;
  const d={...draft},tb=cur;
  await mutate(()=>{
    const t=S.tables[tb]||(S.tables[tb]={items:{}});
    ITEMS.forEach(([k])=>{if(d[k])t.items[k]=Math.round(((t.items[k]||0)+d[k])*100)/100});
    const fi={};FISH.forEach(k=>{if(d[k]>0)fi[k]=d[k]});
    if(Object.keys(fi).length)S.tickets.push({id:S.seq++,table:tb,time:Date.now(),items:fi,done:false,seen:false});
    S.tickets=S.tickets.filter(t=>!(t.done&&t.seen)||Date.now()-t.time<864e5);
  });
  draft={};render();
}
async function closeT(){
  const d={...draft},tb=cur;let sale=null;
  await mutate(()=>{
    sale=null;
    const items={...((S.tables[tb]||{}).items||{})};
    ITEMS.forEach(([k])=>{if(d[k])items[k]=Math.round(((items[k]||0)+d[k])*100)/100});
    if(!money(items))return;
    sale={id:S.sales.length+1,time:Date.now(),table:tb,items,sub:money(items),pct:pctFor(tb),fee:fee(money(items),tb),total:grand(items,tb),prices:{...S.prices}};
    S.sales.push(sale);delete S.tables[tb];
  });
  cur=null;draft={};render();
  if(sale)receipt(sale);
}
function receipt(s){
  const lines=ITEMS.filter(([k])=>s.items[k]).map(([k,n,u])=>`<div class="l"><span>${n} ${kg(s.items[k])} ${u}</span><span>${f(s.items[k]*S.prices[k])}</span></div>`).join('');
  document.getElementById('modal').innerHTML=`<div class="modal"><div><div class="rc"><div style="text-align:center"><b>FAYZ BALIQXONASI</b><br>Chek №${s.id}</div><hr>
  <div>${lbl(s.table)}<br>${new Date(s.time).toLocaleString('uz')}</div><hr>${lines}<hr>
  <div class="l"><span>Taomlar</span><span>${f(s.sub??s.total)}</span></div><div class="l"><span>Xizmat (${s.pct||0}%)</span><span>${f(s.fee||0)}</span></div><div class="l"><b>JAMI:</b><b>${f(s.total)} soʻm</b></div><hr><div style="text-align:center">Rahmat! Yana kutamiz 🐟</div></div>
  <div class="acts" style="margin-top:10px"><button class="btn" onclick="window.print()">🖨 Chop etish</button><button class="btn ghost" onclick="document.getElementById('modal').innerHTML=''">Yopish</button></div></div></div>`;
}

/* ---------- OSHPAZ ---------- */
function cook(){
  const open=S.tickets.filter(t=>!t.done).reverse(),done=S.tickets.filter(t=>t.done).slice(-4).reverse();
  const tk=t=>`<div class="card tk ${t.done?'done':!t.acc?'new':''}" style="margin-bottom:10px"><h3>${lbl(t.table)} <small style="color:var(--mut);font-weight:400">· ${hm(t.time)}</small></h3><ul style="margin:0 0 10px;padding-left:20px">${ITEMS.filter(([k])=>t.items[k]).map(([k,n,u])=>`<li><b>${n}</b> — ${kg(t.items[k])} ${u}</li>`).join('')}</ul>${t.done?'':`${t.acc?`<button class="btn ok" style="width:100%;font-size:18px;padding:16px" onclick="ready(${t.id})">🔥 Baliq pishdi</button>`:`<button class="btn" style="width:100%;font-size:18px;padding:16px" onclick="accept(${t.id})">🔔 Qabul qildim</button>`}`}</div>`;
  return soundBar()+`<h2 style="margin-top:0">Yangi buyurtmalar (${open.length})</h2>${open.map(tk).join('')||'<div class="card" style="color:var(--mut)">Hozircha buyurtma yoʻq</div>'}
  ${done.length?'<h2>Tayyor boʻlganlar</h2>'+done.map(tk).join(''):''}`;
}
function ready(id){mutate(()=>{const t=S.tickets.find(x=>x.id===id);if(t){t.done=true;t.doneAt=Date.now();t.seen=false}})}
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
function accept(id){mutate(()=>{const t=S.tickets.find(x=>x.id===id);if(t)t.acc=true})}
async function newSaboy(){
  let key;await mutate(()=>{S.seqS=(S.seqS||0)+1;key='S'+S.seqS;S.tables[key]={items:{},saboy:true}});
  cur=key;draft={};pick=false;render();
}
function back(){
  const k=cur;cur=null;draft={};render();
  if(isS(k)&&S.tables[k]&&!money(S.tables[k].items))mutate(()=>{delete S.tables[k]});
}

/* ---------- ADMIN ---------- */
let atab='home',aper='today';
const SM=' soʻm';
function setTab(t){atab=t;render()}
function setPer(p){aper=p;render()}
function reprint(id){const x=S.sales.find(y=>y.id===id);if(x)receipt(x)}
const pr=(x,k)=>(x.prices||S.prices)[k]||0;
const nm=k=>ITEMS.find(i=>i[0]===k)[1];
function salesTable(list){
  const fi=x=>FISH.filter(k=>x.items[k]).map(k=>nm(k)+' '+kg(x.items[k])+' kg').join(', ')||'—';
  return `<div class="card scroll"><table class="tt"><thead><tr><th>№</th><th>Vaqt</th><th>Hona</th><th>Baliq</th><th>Non</th><th>Sous</th><th>Fanta</th><th>Cola</th><th class="num">Xizmat</th><th class="num">Jami</th><th></th></tr></thead><tbody>${list.map(x=>`<tr><td>${x.id}</td><td>${new Date(x.time).toLocaleString('uz',{dateStyle:'short',timeStyle:'short'})}</td><td>${lbl(x.table)}</td><td>${fi(x)}</td><td>${x.items.non||0}</td><td>${x.items.sous||0}</td><td>${x.items.fanta||0}</td><td>${x.items.cola||0}</td><td class="num">${f(x.fee||0)}</td><td class="num"><b>${f(x.total)}</b></td><td><button class="btn ghost" style="padding:4px 10px;font-size:13px" onclick="reprint(${x.id})">Chek</button></td></tr>`).join('')||'<tr><td colspan="11" style="color:var(--mut)">Sotuv yoʻq</td></tr>'}</tbody></table></div>`;
}
function admin(){
  const t0=new Date().setHours(0,0,0,0),from=aper==='today'?t0:aper==='week'?t0-6*864e5:0;
  const sl=S.sales.filter(x=>x.time>=from);
  const qty=k=>sl.reduce((a,x)=>a+(x.items[k]||0),0);
  const amt=k=>sl.reduce((a,x)=>a+(x.items[k]||0)*pr(x,k),0);
  const rev=sl.reduce((a,x)=>a+x.total,0),fees=sl.reduce((a,x)=>a+(x.fee||0),0);
  const fishKg=FISH.reduce((a,k)=>a+qty(k),0),fishSum=FISH.reduce((a,k)=>a+amt(k),0);
  const OTH=['non','sous','fanta','cola'];
  const tabs=[['home','📊 Umumiy'],['fish','🐟 Baliq hisoboti'],['other','🥤 Non va ichimlik'],['sales','🧾 Sotuvlar tarixi'],['set','⚙️ Narxlar va sozlama']];
  const pers=[['today','Bugun'],['week','Oxirgi 7 kun'],['all','Hammasi']];
  const kpi=(v,l,c)=>`<div class="card stat kpi" style="border-top-color:${c}"><b>${v}</b><span>${l}</span></div>`;
  const inp=k=>`<div><label>${nm(k)} (soʻm)</label><input type="number" min="0" value="${S.prices[k]}" onchange="setP('${k}',this.value)"></div>`;
  let b='';
  if(atab==='home'){
    const busy=Object.entries(S.tables);
    b=`<div class="grid">${kpi(f(rev)+SM,'Umumiy tushum (xizmat bilan)','var(--pri)')}${kpi(f(rev-fees)+SM,'Taomlar summasi','var(--ok)')}${kpi(f(fees)+SM,'Xizmat haqi','var(--warn)')}${kpi(sl.length,'Chiqarilgan cheklar','var(--mut)')}${kpi(kg(fishKg)+' kg','Sotilgan baliq','var(--pri)')}${kpi(busy.filter(([n])=>!isS(n)).length+' / '+ROOMS,'Hozir band honalar','var(--bad)')}</div>
    <h2>Hozir band honalar</h2><div class="card">${busy.map(([n,t])=>`<div class="row"><div class="n"><b>${lbl(n)}</b></div><div class="sum">${f(grand(t.items,n))}${SM}</div></div>`).join('')||'<span style="color:var(--mut)">Hamma hona boʻsh</span>'}</div>
    <h2>Oxirgi cheklar</h2>${salesTable(sl.slice(-5).reverse())}`;
  }else if(atab==='fish'){
    b=`<div class="card scroll"><table class="tt"><thead><tr><th>Baliq turi</th><th class="num">Narxi (1 kg)</th><th class="num">Sotilgan</th><th class="num">Summa</th><th>Ulushi</th></tr></thead><tbody>${FISH.map(k=>{const p=fishKg?qty(k)/fishKg*100:0;return `<tr><td><b>${nm(k)}</b></td><td class="num">${f(S.prices[k])}</td><td class="num">${kg(qty(k))} kg</td><td class="num">${f(amt(k))}</td><td style="min-width:110px"><div class="bar"><i style="width:${p}%"></i></div><small>${Math.round(p)}%</small></td></tr>`}).join('')}</tbody><tfoot><tr><td colspan="2">Jami baliq</td><td class="num">${kg(fishKg)} kg</td><td class="num">${f(fishSum)}</td><td></td></tr></tfoot></table></div>`;
  }else if(atab==='other'){
    b=`<div class="card scroll"><table class="tt"><thead><tr><th>Mahsulot</th><th class="num">Narxi</th><th class="num">Sotilgan</th><th class="num">Summa</th></tr></thead><tbody>${OTH.map(k=>`<tr><td><b>${nm(k)}</b></td><td class="num">${f(S.prices[k])}</td><td class="num">${kg(qty(k))} dona</td><td class="num">${f(amt(k))}</td></tr>`).join('')}</tbody><tfoot><tr><td colspan="3">Jami</td><td class="num">${f(OTH.reduce((a,k)=>a+amt(k),0))}</td></tr></tfoot></table></div>`;
  }else if(atab==='sales'){
    b=salesTable(sl.slice().reverse());
  }else{
    b=`<h2 style="margin-top:0">🐟 Baliq narxlari (1 kg)</h2><div class="pr">${FISH.map(inp).join('')}</div><h2>🥤 Non va ichimliklar (1 dona)</h2><div class="pr">${OTH.map(inp).join('')}</div><h2>Xizmat haqi</h2><div class="pr"><div><label>Foiz (%)</label><input type="number" min="0" max="100" value="${svc()}" onchange="setSvc(this.value)"></div></div><h2>Xavfli boʻlim</h2><button class="btn bad" onclick="resetAll()">Barcha sotuvlarni tozalash</button>`;
  }
  return `<div class="adm"><aside class="side">${tabs.map(([k,t])=>`<button class="${atab===k?'on':''}" onclick="setTab('${k}')">${t}</button>`).join('')}</aside><section>${atab==='set'?'':`<div class="per">${pers.map(([k,t])=>`<button class="${aper===k?'on':''}" onclick="setPer('${k}')">${t}</button>`).join('')}</div>`}${b}</section></div>`;
}
function setSvc(v){mutate(()=>{S.service=Math.min(100,Math.max(0,parseFloat(v)||0))})}
function setP(k,v){mutate(()=>{S.prices[k]=Math.max(0,parseFloat(v)||0)})}
function resetAll(){if(confirm('Hamma sotuvlar va buyurtmalar oʻchiriladi. Davom etasizmi?'))mutate(()=>{const p=S.prices,sv=svc();S=norm(JSON.parse(JSON.stringify(DEF)));S.prices=p;S.service=sv;cur=null})}

/* ---------- SERVER BILAN ALOQA ---------- */
function norm(x){x=x||{};x.prices={...DEF.prices,...(x.prices||{})};x.tables=x.tables||{};x.tickets=x.tickets||[];x.sales=x.sales||[];x.seq=x.seq||1;if(x.service==null)x.service=10;return x}
function apply(d){S=norm(d.state);rev=d.rev}
function status(ok){const e=document.getElementById('st');if(e){e.textContent=ok?'\u25cf onlayn':'\u25cf aloqa yoʻq';e.style.color=ok?'var(--ok)':'var(--bad)'}}
async function mutate(fn){
  for(let i=0;i<6;i++){
    fn();
    try{
      const r=await fetch('/api/state',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({rev,state:S})});
      const d=await r.json();
      if(r.status===409){apply(d);continue}   // boshqa qurilma oldin yozgan: yangi holatda qayta urinamiz
      rev=d.rev;status(true);render();return true;
    }catch(e){status(false);alert('Server bilan aloqa yoʻq. Qayta urinib koʻring.');try{apply(await(await fetch('/api/state')).json())}catch(_){}render();return false}
  }
}
function boot(){
  const n=x=>x.tickets.filter(t=>t.done).length;
  const es=new EventSource('/api/events');
  es.onmessage=e=>{const o=S;apply(JSON.parse(e.data));if(rev>1&&n(S)>n(o)&&route()!=='cook')beep();status(true);render()};
  es.onerror=()=>status(false);
}
render();boot();
