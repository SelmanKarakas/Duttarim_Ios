// Export the approved splash masters without changing their composition.
const fs=require('node:fs'),path=require('node:path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..');
const art=path.join(root,'artwork/splash-card');
(async()=>{
  const ios=path.join(root,'ios/App/App/Assets.xcassets/Splash.imageset');
  for(const theme of ['light','dark'])fs.copyFileSync(path.join(art,`splash-${theme}.png`),path.join(ios,`splash-${theme}.png`));
  if(!process.env.ANDROID_ROOT)return;
  const android=process.env.ANDROID_ROOT;
  for(const name of ['dutar-head.png','TamDuttar.png'])fs.copyFileSync(path.join(root,'www',name),path.join(android,'www',name));
  const res=path.join(android,'android/app/src/main/res');
  for(const [theme,dir] of [['light','drawable-nodpi'],['dark','drawable-night-nodpi']]){
    fs.mkdirSync(path.join(res,dir),{recursive:true});
    fs.copyFileSync(path.join(art,`splash-${theme}.png`),path.join(res,dir,'branded_splash.png'));
  }
  await sharp(path.join(root,'www/dutar-head.png')).resize(540,540).png().toFile(path.join(res,'drawable/splash_image.png'));
})().catch(error=>{console.error(error);process.exitCode=1;});
