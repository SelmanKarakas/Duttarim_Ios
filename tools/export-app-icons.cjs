// Package the generated artwork at each platform's existing icon dimensions.
const fs=require('node:fs'),path=require('node:path');
const sharp=require(process.env.SHARP_MODULE||'sharp');
const root=path.resolve(__dirname,'..');
const icon=path.join(root,'artwork/app-icon.png');
(async()=>{
  const ios=path.join(root,'ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png');
  if(fs.existsSync(ios))await sharp(icon).resize(1024,1024).removeAlpha().png().toFile(ios);
  if(!process.env.ANDROID_ROOT)return;
  const res=path.join(process.env.ANDROID_ROOT,'android/app/src/main/res');
  for(const dir of fs.readdirSync(res).filter(name=>/^mipmap-(mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi)$/.test(name))){
    for(const name of ['ic_launcher.webp','ic_launcher_round.webp','ic_launcher_foreground.webp']){
      const dest=path.join(res,dir,name),{width,height}=await sharp(fs.readFileSync(dest)).metadata();
      let output;
      if(name.includes('foreground')){
        const size=Math.round(width*70/108),offset=Math.round((width-size)/2);
        const head=await sharp(path.join(root,'www/dutar-head.png')).resize(size,size).png().toBuffer();
        output=sharp({create:{width,height,channels:4,background:'#0000'}}).composite([{input:head,left:offset,top:offset}]);
      }else{
        const round=name.includes('round'),inset=round?0:Math.round(width/24);
        const svg=round?`<svg width="${width}" height="${height}"><circle cx="${width/2}" cy="${height/2}" r="${width/2}" fill="white"/></svg>`:`<svg width="${width}" height="${height}"><rect x="${inset}" y="${inset}" width="${width-2*inset}" height="${height-2*inset}" rx="${width/5}" fill="white"/></svg>`;
        output=sharp(icon).resize(width,height).ensureAlpha().composite([{input:Buffer.from(svg),blend:'dest-in'}]);
      }
      const buffer=await output.webp({lossless:true}).toBuffer();fs.writeFileSync(dest,buffer);
    }
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
