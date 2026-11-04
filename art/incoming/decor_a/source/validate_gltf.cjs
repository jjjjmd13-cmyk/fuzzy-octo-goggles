// npm install gltf-validator; NODE_PATH=<module directory> node validate_gltf.cjs
const fs=require('fs'),path=require('path'),v=require('gltf-validator');
(async()=>{const dir=path.resolve(__dirname,'..'),report=[];
for(const f of fs.readdirSync(dir).filter(f=>f.endsWith('.glb'))){
const r=await v.validateBytes(new Uint8Array(fs.readFileSync(path.join(dir,f))),{uri:f,maxIssues:100});report.push({file:f,...r});console.log(f,r.issues.numErrors,r.issues.numWarnings);}
fs.writeFileSync(path.join(dir,'validation_khronos.json'),JSON.stringify(report,null,2)+'\n');if(report.some(r=>r.issues.numErrors||r.issues.numWarnings))process.exitCode=1;
})();
