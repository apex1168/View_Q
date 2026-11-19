// Requires: npm install --prefix .tools/checks --no-audit --no-fund xcode@3.0.1
// Structural verification only; does not replace xcodebuild on a Mac.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const xcode = require('../.tools/checks/node_modules/xcode');
const project = xcode.project('ios/Runner.xcodeproj/project.pbxproj');
project.parseSync();
const objects = project.hash.project.objects;
const key = x => typeof x === 'string' ? x : x.value;
const targets = Object.entries(objects.PBXNativeTarget).filter(([,x]) => typeof x === 'object');
const runner = targets.find(([,x]) => x.name === 'Runner')[1];
const [extensionID, extension] = targets.find(([,x]) => x.name === 'ViewQShare');
assert.equal(extension.productType,'"com.apple.product-type.app-extension"');
assert(runner.dependencies.some(x => objects.PBXTargetDependency[key(x)]?.target === extensionID));
const copy = runner.buildPhases.map(x => objects.PBXCopyFilesBuildPhase[key(x)]).find(x => Number(x?.dstSubfolderSpec) === 13);
assert(copy.files.some(x => objects.PBXBuildFile[key(x)].fileRef === extension.productReference));
for (const target of [runner, extension]) {
  const configs = objects.XCConfigurationList[target.buildConfigurationList].buildConfigurations;
  for (const ref of configs) {
    const settings = objects.XCBuildConfiguration[key(ref)].buildSettings;
    assert(fs.existsSync('ios/' + settings.INFOPLIST_FILE));
    assert(fs.existsSync('ios/' + settings.CODE_SIGN_ENTITLEMENTS));
  }
}
const sources = runner.buildPhases.map(x => objects.PBXSourcesBuildPhase[key(x)]).filter(Boolean).flatMap(x => x.files);
assert(sources.length >= 6);
assert(fs.statSync('assets/tessdata/eng.traineddata').size === 15400601);
console.log('PASS: Xcode project parses, extension is embedded with a dependency, signing files exist, sources and English data are present.');
