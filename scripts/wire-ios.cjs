// One-time project wiring, retained so the Xcode changes are reviewable.
// Do not run after manually changing the project: it intentionally refuses a second run.
const fs = require('node:fs');
const file = 'ios/Runner.xcodeproj/project.pbxproj';
let p = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
if (p.includes('VQShareExtension')) throw new Error('View Q is already wired');
const id = n => 'A0B0C0D0E0F00000' + n.toString(16).toUpperCase().padStart(8, '0');
function section(name, content) { p = p.replace(`/* End ${name} section */`, content + `\n/* End ${name} section */`); }
function into(object, key, content) {
  const match = new RegExp(`^\\s*${object}(?: /\\*[^\\n]*?\\*/)? = \\{`, 'm').exec(p);
  const start = match ? match.index : -1;
  if (start < 0) throw new Error('Missing object ' + object);
  const where = p.indexOf(`${key} = (`, start);
  if (where < 0) throw new Error('Missing list ' + key);
  const end = where + `${key} = (`.length;
  p = p.slice(0,end) + '\n' + content + p.slice(end);
}
const sources = ['Runner/LibraryStore.swift','Runner/OcrQueue.swift','Shared/SharedInbox.swift'];
sources.forEach((path,i) => {
  section('PBXFileReference', `${id(10+i)} /* ${path} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${path}; sourceTree = SOURCE_ROOT; };`);
  section('PBXBuildFile', `${id(20+i)} = {isa = PBXBuildFile; fileRef = ${id(10+i)}; };`);
  into('97C146EA1CF9000F007C117D','files',`${id(20+i)},`);
  into('97C146E51CF9000F007C117D','children',`${id(10+i)},`);
});
section('PBXFileReference', `
${id(30)} = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShareExtension/ShareViewController.swift; sourceTree = SOURCE_ROOT; };
${id(31)} = {isa = PBXFileReference; explicitFileType = wrapper.app-extension; path = ViewQShare.appex; sourceTree = BUILT_PRODUCTS_DIR; };
${id(32)} = {isa = PBXFileReference; lastKnownFileType = folder; path = ../assets/tessdata; sourceTree = SOURCE_ROOT; };
`);
into('97C146E51CF9000F007C117D','children',`${id(30)},\n${id(32)},`);
into('97C146EF1CF9000F007C117D','children',`${id(31)},`);
section('PBXBuildFile', `
${id(40)} = {isa = PBXBuildFile; fileRef = ${id(30)}; };
${id(41)} = {isa = PBXBuildFile; fileRef = ${id(12)}; };
${id(42)} = {isa = PBXBuildFile; fileRef = ${id(31)}; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
${id(43)} = {isa = PBXBuildFile; fileRef = ${id(32)}; };
${id(44)} = {isa = PBXBuildFile; productRef = ${id(80)}; };
`);
into('97C146EC1CF9000F007C117D','files',`${id(43)},`);
into('97C146EB1CF9000F007C117D','files',`${id(44)},`);
into('97C146ED1CF9000F007C117D','buildPhases',`${id(50)},`);
into('97C146ED1CF9000F007C117D','dependencies',`${id(60)},`);
into('97C146ED1CF9000F007C117D','packageProductDependencies',`${id(80)},`);
into('97C146E61CF9000F007C117D','targets',`${id(70)},`);
into('97C146E61CF9000F007C117D','packageReferences',`${id(81)},`);
section('PBXCopyFilesBuildPhase', `${id(50)} = {isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = (${id(42)},); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0; };`);
section('PBXContainerItemProxy', `${id(61)} = {isa = PBXContainerItemProxy; containerPortal = 97C146E61CF9000F007C117D; proxyType = 1; remoteGlobalIDString = ${id(70)}; remoteInfo = ViewQShare; };`);
section('PBXTargetDependency', `${id(60)} = {isa = PBXTargetDependency; target = ${id(70)}; targetProxy = ${id(61)}; };`);
section('PBXSourcesBuildPhase', `${id(71)} = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${id(40)},${id(41)},); runOnlyForDeploymentPostprocessing = 0; };`);
section('PBXFrameworksBuildPhase', `${id(72)} = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };`);
section('PBXResourcesBuildPhase', `${id(73)} = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };`);
section('PBXNativeTarget', `${id(70)} /* VQShareExtension */ = {isa = PBXNativeTarget; buildConfigurationList = ${id(74)}; buildPhases = (${id(71)},${id(72)},${id(73)},); buildRules = (); dependencies = (); name = ViewQShare; productName = ViewQShare; productReference = ${id(31)}; productType = "com.apple.product-type.app-extension"; };`);
['Debug','Release','Profile'].forEach((name,i) => section('XCBuildConfiguration', `${id(90+i)} = {isa = XCBuildConfiguration; buildSettings = {
APPLICATION_EXTENSION_API_ONLY = YES;
CLANG_ENABLE_MODULES = YES;
CODE_SIGN_ENTITLEMENTS = ShareExtension/ShareExtension.entitlements;
CODE_SIGN_STYLE = Automatic;
CURRENT_PROJECT_VERSION = 1;
GENERATE_INFOPLIST_FILE = NO;
INFOPLIST_FILE = ShareExtension/Info.plist;
IPHONEOS_DEPLOYMENT_TARGET = 15.0;
LD_RUNPATH_SEARCH_PATHS = ("$(inherited)","@executable_path/Frameworks","@executable_path/../../Frameworks",);
MARKETING_VERSION = 1.0.0;
PRODUCT_BUNDLE_IDENTIFIER = org.viewq.viewq.Share;
PRODUCT_NAME = "$(TARGET_NAME)";
SDKROOT = iphoneos;
SKIP_INSTALL = YES;
SWIFT_VERSION = 5.0;
TARGETED_DEVICE_FAMILY = "1,2";
}; name = ${name}; };`));
section('XCConfigurationList', `${id(74)} = {isa = XCConfigurationList; buildConfigurations = (${id(90)},${id(91)},${id(92)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };`);
section('XCSwiftPackageProductDependency', `${id(80)} = {isa = XCSwiftPackageProductDependency; package = ${id(81)}; productName = libtesseract; };`);
p = p.replace('/* Begin XCLocalSwiftPackageReference section */', `/* Begin XCRemoteSwiftPackageReference section */
${id(81)} = {isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/SwiftyTesseract/libtesseract.git"; requirement = {kind = exactVersion; version = 0.2.0; }; };
/* End XCRemoteSwiftPackageReference section */
/* Begin XCLocalSwiftPackageReference section */`);
p = p.replaceAll('INFOPLIST_FILE = Runner/Info.plist;', 'INFOPLIST_FILE = Runner/Info.plist;\nCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\nOTHER_LDFLAGS = ("$(inherited)","-lsqlite3","-lz","-lc++",);');
fs.writeFileSync(file,p);
