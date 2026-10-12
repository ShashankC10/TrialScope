#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project. No third-party project generator needed."""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def ref(name): return uid(name)
objects = {}
def add(name, content): objects[uid(name)] = content
add('project', f'''isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {ref('app')} = {{ CreatedOnToolsVersion = 16.0; }}; {ref('uitests')} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {ref('app')}; }}; }}; }}; buildConfigurationList = {ref('projectConfigs')}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {ref('root')}; packageReferences = ({ref('package')}); productRefGroup = {ref('products')}; projectDirPath = ""; projectRoot = ""; targets = ({ref('app')}, {ref('uitests')});''')
add('root',f'isa = PBXGroup; children = ({ref("appGroup")}, {ref("testGroup")}, {ref("products")}); sourceTree = "<group>";')
add('appGroup',f'isa = PBXGroup; children = ({ref("appSource")}, {ref("assets")}, {ref("privacy")}); path = App; sourceTree = "<group>";')
add('testGroup',f'isa = PBXGroup; children = ({ref("testSource")}); path = TrialScopeUITests; sourceTree = "<group>";')
add('products',f'isa = PBXGroup; children = ({ref("appProduct")}, {ref("testProduct")}); name = Products; sourceTree = "<group>";')
for name,path,kind in [('appSource','TrialScopeApp.swift','sourcecode.swift'),('testSource','TrialScopeUITests.swift','sourcecode.swift'),('assets','Assets.xcassets','folder.assetcatalog'),('privacy','PrivacyInfo.xcprivacy','text.xml')]:
 add(name,f'isa = PBXFileReference; lastKnownFileType = {kind}; path = {path}; sourceTree = "<group>";')
 add(name+'Build',f'isa = PBXBuildFile; fileRef = {ref(name)};')
add('appProduct','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = TrialScope.app; sourceTree = BUILT_PRODUCTS_DIR;')
add('testProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = TrialScopeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
add('package','isa = XCLocalSwiftPackageReference; relativePath = Packages/TrialKit;')
for product in ['TrialCore','TrialUI']:
 add(product,f'isa = XCSwiftPackageProductDependency; productName = {product};')
 add(product+'Build',f'isa = PBXBuildFile; productRef = {ref(product)};')
for target,source in [('app','appSource'),('uitests','testSource')]:
 add(target+'Sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({ref(source+"Build")}); runOnlyForDeploymentPostprocessing = 0;')
 resources = ','.join(ref(n+'Build') for n in ['assets','privacy']) if target == 'app' else ''
 add(target+'Resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({resources}); runOnlyForDeploymentPostprocessing = 0;')
 frameworks = ','.join(ref(n+'Build') for n in ['TrialCore','TrialUI']) if target == 'app' else ''
 add(target+'Frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({frameworks}); runOnlyForDeploymentPostprocessing = 0;')
 product = 'appProduct' if target == 'app' else 'testProduct'
 name = 'TrialScope' if target == 'app' else 'TrialScopeUITests'
 ptype = 'application' if target == 'app' else 'bundle.ui-testing'
 deps = ref('testDependency') if target == 'uitests' else ''
 products = ','.join(ref(n) for n in ['TrialCore','TrialUI']) if target == 'app' else ''
 add(target,f'''isa = PBXNativeTarget; buildConfigurationList = {ref(target+'Configs')}; buildPhases = ({ref(target+'Sources')}, {ref(target+'Frameworks')}, {ref(target+'Resources')}); buildRules = (); dependencies = ({deps}); name = {name}; packageProductDependencies = ({products}); productName = {name}; productReference = {ref(product)}; productType = "com.apple.product-type.{ptype}";''')
add('proxy',f'isa = PBXContainerItemProxy; containerPortal = {ref("project")}; proxyType = 1; remoteGlobalIDString = {ref("app")}; remoteInfo = TrialScope;')
add('testDependency',f'isa = PBXTargetDependency; target = {ref("app")}; targetProxy = {ref("proxy")};')
for scope in ['project','app','uitests']:
 for mode in ['Debug','Release']:
  settings = {'SWIFT_VERSION':'6.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','CLANG_ENABLE_MODULES':'YES','SWIFT_STRICT_CONCURRENCY':'complete'}
  if scope == 'project':
   settings.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO','ONLY_ACTIVE_ARCH':'YES' if mode=='Debug' else 'NO'})
   if mode == 'Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG $(inherited)'
  else:
   settings.update({'CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.shashank.TrialScope'+('.UITests' if scope=='uitests' else ''),'CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','SWIFT_EMIT_LOC_STRINGS':'YES'})
   if scope=='app': settings.update({'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'})
   else: settings['TEST_TARGET_NAME']='TrialScope'
  body=' '.join(f'{k} = "{v}";' for k,v in settings.items())
  add(scope+mode,f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {mode};')
 add(scope+'Configs',f'isa = XCConfigurationList; buildConfigurations = ({ref(scope+"Debug")}, {ref(scope+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
text='// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'
text+='\n'.join(f'{key} = {{ {value} }};' for key,value in objects.items())
text+='\n}; rootObject = '+ref('project')+'; }\n'
(ROOT/'TrialScope.xcodeproj/project.pbxproj').write_text(text)
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('app')}" BuildableName="TrialScope.app" BlueprintName="TrialScope" ReferencedContainer="container:TrialScope.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('uitests')}" BuildableName="TrialScopeUITests.xctest" BlueprintName="TrialScopeUITests" ReferencedContainer="container:TrialScope.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('app')}" BuildableName="TrialScope.app" BlueprintName="TrialScope" ReferencedContainer="container:TrialScope.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('app')}" BuildableName="TrialScope.app" BlueprintName="TrialScope" ReferencedContainer="container:TrialScope.xcodeproj"/></BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(ROOT/'TrialScope.xcodeproj/xcshareddata/xcschemes/TrialScope.xcscheme').write_text(scheme)
print('Generated TrialScope.xcodeproj')
