// Fayz baliqxonasi serveri. Ishga tushirish: node server.js
const http=require('http'),fs=require('fs'),path=require('path'),os=require('os');
const PORT=process.env.PORT||3000, ADMIN_PASS=process.env.ADMIN_PASS||'1234'; // admin paroli
const ROOT=__dirname, DATA=path.join(ROOT,'data.json');
const MIME={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.svg':'image/svg+xml','.png':'image/png','.jpg':'image/jpeg','.ico':'image/x-icon'};
let db={rev:1,state:{}};
try{db=JSON.parse(fs.readFileSync(DATA,'utf8'))}catch(e){}
const clients=new Set();
function persist(){try{fs.writeFileSync(DATA+'.tmp',JSON.stringify(db));fs.renameSync(DATA+'.tmp',DATA)}catch(e){console.error(e)}}
function broadcast(){const m=`data: ${JSON.stringify(db)}\n\n`;clients.forEach(c=>c.write(m))}
setInterval(()=>clients.forEach(c=>c.write(': ping\n\n')),25000);
const json=(res,code,o)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(o))};
http.createServer((req,res)=>{
  const url=req.url.split('?')[0];
  if(url==='/api/state'&&req.method==='GET')return json(res,200,db);
  if(url==='/api/state'&&req.method==='POST'){
    let b='';req.on('data',c=>{b+=c;if(b.length>2e7)req.destroy()});
    req.on('end',()=>{try{const x=JSON.parse(b);
      if(x.rev!==db.rev)return json(res,409,db);      // kimdir oldinroq oʻzgartirgan
      db={rev:db.rev+1,state:x.state};persist();broadcast();json(res,200,{rev:db.rev});
    }catch(e){json(res,400,{error:'bad'})}});return;
  }
  if(url==='/api/events'){
    res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-cache',Connection:'keep-alive'});
    res.write(`data: ${JSON.stringify(db)}\n\n`);clients.add(res);req.on('close',()=>clients.delete(res));return;
  }
  const page=['/','/admin','/waiter','/cook'].includes(url);
  if(url==='/admin'){
    const a=(req.headers.authorization||'').split(' ')[1]||'';
    const pass=Buffer.from(a,'base64').toString().split(':').slice(1).join(':');
    if(pass!==ADMIN_PASS){res.writeHead(401,{'WWW-Authenticate':'Basic realm="Admin"'});return res.end('Parol kerak')}
  }
  if(!page&&!/^\/(css|js|images)\//.test(url)){res.writeHead(404);return res.end('Topilmadi')}
  const file=path.join(ROOT,page?'index.html':decodeURIComponent(url));
  if(!file.startsWith(ROOT)){res.writeHead(403);return res.end()}
  fs.readFile(file,(e,d)=>{
    if(e){res.writeHead(404);return res.end('Topilmadi')}
    res.writeHead(200,{'Content-Type':MIME[path.extname(file)]||'application/octet-stream','Cache-Control':'no-cache'});res.end(d);
  });
}).listen(PORT,'0.0.0.0',()=>{
  console.log('\nFayz baliqxonasi serveri ishga tushdi!\n');
  Object.values(os.networkInterfaces()).flat().filter(i=>i.family==='IPv4'&&!i.internal).forEach(i=>{
    console.log(`Boshqa kompyuterlarda oching (${i.address}):`);
    console.log(`  Ofitsiant: http://${i.address}:${PORT}/waiter`);
    console.log(`  Oshpaz:    http://${i.address}:${PORT}/cook`);
    console.log(`  Admin:     http://${i.address}:${PORT}/admin   (parol: ${ADMIN_PASS})\n`);
  });
});
