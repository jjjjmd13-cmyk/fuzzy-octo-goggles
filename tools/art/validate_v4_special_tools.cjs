const fs=require('fs');const path=require('path');const v=require('gltf-validator');
(async()=>{let root=process.argv[2],dir=path.join(root,'art/incoming/special_tools'),report=[];
for (const name of Object.keys(JSON.parse(fs.readFileSync(path.join(dir,'validation.json'))))){const p=path.join(root,'assets/models/tools',name+'.glb');let r=await v.validateBytes(new Uint8Array(fs.readFileSync(p)),{uri:name+'.glb',maxIssues:100});report.push({name,...r});console.log(name,r.issues.numErrors,r.issues.numWarnings);}
fs.writeFileSync(path.join(dir,'khronos_validation.json'),JSON.stringify(report,null,2)+'\n');if(report.some(r=>r.issues.numErrors||r.issues.numWarnings))process.exitCode=1;
})();
