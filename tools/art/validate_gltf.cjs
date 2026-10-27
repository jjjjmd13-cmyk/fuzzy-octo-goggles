// Run with NODE_PATH pointing to an installed Khronos gltf-validator package.
const fs=require('fs'),path=require('path'),validator=require('gltf-validator');
(async()=>{
 const root=path.resolve(__dirname,'../..');
 const files=process.argv.slice(2);
 const reports=[];
 for(const file of files){
  const report=await validator.validateBytes(new Uint8Array(fs.readFileSync(path.join(root,file))),{uri:file});
  reports.push({file,validatorVersion:report.validatorVersion,issues:report.issues});
 }
 process.stdout.write(JSON.stringify(reports,null,2)+'\n');
 if(reports.some(r=>r.issues.numErrors||r.issues.numWarnings))process.exitCode=1;
})();
