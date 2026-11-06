// Package the transparent logo directly; platform masks provide the icon shape.
const fs=require('node:fs'),path=require('node:path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..');
(async()=>{
 const logo=await sharp(path.join(root,'www/dutar-head.png')).trim().png().toBuffer();
 async function render(width,height,foreground=false){
  const size=Math.round(width*(foreground?0.60:0.78));
  const mark=await sharp(logo).resize(size,size,{fit:'inside'}).png().toBuffer();
  return sharp({create:{width,height,channels:4,background:foreground?'#0000':'#F7FAFC'}}).composite([{input:mark,gravity:'centre'}]);
 }
 const master=await render(1024,1024);
 const buffer=await master.removeAlpha().png().toBuffer();
 fs.writeFileSync(path.join(root,'artwork/app-icon.png'),buffer);
 fs.writeFileSync(path.join(root,'ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png'),buffer);
 if(!process.env.ANDROID_ROOT)return;
 const res=path.join(process.env.ANDROID_ROOT,'android/app/src/main/res');
 for(const dir of fs.readdirSync(res).filter(n=>/^mipmap-(mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi)$/.test(n))){
  for(const name of ['ic_launcher.webp','ic_launcher_round.webp','ic_launcher_foreground.webp']){
   const dest=path.join(res,dir,name),{width,height}=await sharp(fs.readFileSync(dest)).metadata();
   const output=await render(width,height,name.includes('foreground'));
   fs.writeFileSync(dest,await output.webp({lossless:true}).toBuffer());
  }
 }
})();
