const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const root=process.env.APP_ROOT||path.resolve(__dirname,'../www');
const server=http.createServer((req,res)=>{
  try{
    const file=path.join(root,req.url.split('?')[0]==='/'?'index.html':req.url.split('?')[0]);
    let body=fs.readFileSync(file);
    if(file.endsWith('app.js'))body=Buffer.from(body.toString().replace('})();','playCompletionFeedback=async function(){};window.confirmationTest={complete:completeActiveString};})();'));
    res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.css')?'text/css':file.endsWith('.json')?'application/json':file.endsWith('.png')?'image/png':'text/html');res.end(body);
  }catch{res.writeHead(404);res.end();}
});
(async()=>{
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const browser=await chromium.launch({channel:'chrome',headless:true});
  try{
    for(const theme of ['light','dark'])for(const width of [390,820]){
      const context=await browser.newContext({viewport:{width,height:width===390?844:1180}});
      await context.route(/https:\/\//,route=>route.abort());
      await context.addInitScript(()=>localStorage.setItem('onboardingDone','1'));
      const page=await context.newPage(),errors=[];page.on('pageerror',error=>errors.push(error.message));
      await page.goto('http://127.0.0.1:'+server.address().port);
      await page.evaluate(theme=>DuttarTheme.apply(theme),theme);
      await page.evaluate(()=>confirmationTest.complete());
      assert.equal(await page.locator('.string-card.completed').count(),1);
      assert.equal(await page.locator('.string-card.completed.active').count(),0);
      await page.waitForFunction(expected=>getComputedStyle(document.querySelector('.string-card.completed')).backgroundColor===expected,theme==='dark'?'rgb(24, 49, 41)':'rgb(237, 247, 240)');
      const surface=await page.locator('.string-card.completed').evaluate(e=>getComputedStyle(e).backgroundColor);
      assert.equal(surface,theme==='dark'?'rgb(24, 49, 41)':'rgb(237, 247, 240)');
      await page.evaluate(()=>confirmationTest.complete());
      assert.equal(await page.locator('.string-card.completed').count(),2);
      await page.waitForTimeout(750);
      assert.equal(await page.locator('.tuner-card.all-complete').count(),1);
      assert.equal(await page.locator('#tuningCompleteMessage').isVisible(),true);
      assert.equal(await page.locator('.completion-check').evaluate(e=>getComputedStyle(e).strokeDashoffset),'0px');
      if(process.env.UI_SCREENSHOTS)await page.screenshot({path:path.join(process.env.UI_SCREENSHOTS,`tuner-confirmation-${theme}-${width}.png`)});
      await page.waitForFunction(()=>document.querySelector('#tuningCompleteMessage').hidden);
      assert.equal(await page.locator('.string-card.completed').count(),2);
      assert.deepEqual(errors,[]);
      await context.close();console.log(`PASS ${theme} ${width}: single-string handoff, both strings confirmed, themed surfaces, animated check and retained state`);
    }
  }finally{await browser.close();server.close();}
})().catch(error=>{console.error(error);process.exitCode=1;server.close();});
