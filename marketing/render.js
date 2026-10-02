const {chromium}=require('/opt/node22/lib/node_modules/playwright');
(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome'});
for(const [n,w,h,m] of [['icon_512',512,512,'icon'],['thumbnail_1920x1080',1920,1080,'th']]){
const p=await b.newPage({viewport:{width:w,height:h}});
await p.goto(`file://${__dirname}/art.html?w=${w}&h=${h}&m=${m}`);await p.waitForTimeout(2500);
await p.screenshot({path:n+'.png'});}
await b.close()})();
