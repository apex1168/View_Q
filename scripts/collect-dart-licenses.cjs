const fs = require('node:fs');
const path = require('node:path');
const {fileURLToPath,pathToFileURL} = require('node:url');
const config = path.resolve('.dart_tool/package_config.json');
const packages = JSON.parse(fs.readFileSync(config,'utf8')).packages;
for (const item of packages) {
  if(item.name === 'view_q') continue;
  const root = fileURLToPath(new URL(item.rootUri,pathToFileURL(config)));
  const license = ['LICENSE','LICENSE.md','LICENSE.txt'].map(x=>path.join(root,x)).find(x=>fs.existsSync(x));
  if(license) fs.copyFileSync(license,path.join('licenses',`${item.name}-LICENSE`));
}
