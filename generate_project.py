import os, uuid

SWIFT_FILES = [
    "ReaderApp/ReaderApp.swift",
    "ReaderApp/Models/Book.swift",
    "ReaderApp/Models/BookSource.swift",
    "ReaderApp/Services/ReaderAPI.swift",
    "ReaderApp/Services/ServerManager.swift",
    "ReaderApp/Views/MainTabView.swift",
    "ReaderApp/Views/ReaderView.swift",
    "ReaderApp/Views/SearchView.swift",
    "ReaderApp/Views/SettingsView.swift",
    "ReaderApp/Views/SetupView.swift",
    "ReaderApp/Views/ShelfView.swift",
]

def uid():
    return uuid.uuid4().hex.upper()[:24]

file_refs = {}
for p in SWIFT_FILES:
    file_refs[p] = uid()

infoid = uid()
assetsid = uid()
product_ref = uid()

# PBXBuildFile
build_files = {}
for p in SWIFT_FILES:
    build_files[p] = uid()

# Groups
root_group = uid()
reader_group = uid()
product_group = uid()

# Target
target_id = uid()
target_config_list = uid()
sources_phase = uid()
frameworks_phase = uid()
resources_phase = uid()

# Configs
debug_config = uid()
release_config = uid()
project_debug_config = uid()
project_release_config = uid()
project_config_list = uid()
project_id = uid()

# Build lines
lines = [
    '// !$*UTF8*$!',
    '{',
    '\tarchiveVersion = 1;',
    '\tclasses = {',
    '\t};',
    '\tobjectVersion = 56;',
    '\tobjects = {',
]

# File references
base = 'sourcecode.swift; fileEncoding = 4'
for p, fid in file_refs.items():
    lines.append(f'\t\t{fid} /* {os.path.basename(p)} */ = {{isa = PBXFileReference; explicitFileType = {base}; name = {os.path.basename(p)!r}; path = {p!r}; sourceTree = SOURCE_ROOT; }};')

lines.append(f'\t\t{infoid} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = "Info.plist"; path = "ReaderApp/Info.plist"; sourceTree = SOURCE_ROOT; }};')
lines.append(f'\t\t{assetsid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = "Assets.xcassets"; path = "ReaderApp/Assets.xcassets"; sourceTree = SOURCE_ROOT; }};')
lines.append(f'\t\t{product_ref} /* ReaderApp.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ReaderApp.app; sourceTree = BUILT_PRODUCTS_DIR; }};')

# Build files
for p, bid in build_files.items():
    fid = file_refs[p]
    lines.append(f'\t\t{bid} /* {os.path.basename(p)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid}; }};')

# Groups
children_ids = list(file_refs.values()) + [infoid, assetsid]
lines.append(f'\t\t{reader_group} = {{isa = PBXGroup; children = ( {" ".join(children_ids)} ); name = ReaderApp; path = ReaderApp; sourceTree = SOURCE_ROOT; }};')
lines.append(f'\t\t{product_group} = {{isa = PBXGroup; children = ( {product_ref} ); name = Products; sourceTree = "<group>"; }};')
lines.append(f'\t\t{root_group} = {{isa = PBXGroup; children = ( {reader_group}, {product_group} ); sourceTree = "<group>"; }};')

# Build phases
lines.append(f'\t\t{sources_phase} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ( {" ".join(build_files.values())} ); runOnlyForDeploymentPostprocessing = 0; }};')
lines.append(f'\t\t{frameworks_phase} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }};')
lines.append(f'\t\t{resources_phase} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }};')

# Target
lines.append(f'\t\t{target_id} /* ReaderApp */ = {{isa = PBXNativeTarget; buildConfigurationList = {target_config_list}; buildPhases = ( {sources_phase}, {frameworks_phase}, {resources_phase} ); buildRules = ( ); dependencies = ( ); name = ReaderApp; productName = ReaderApp; productReference = {product_ref}; productType = "com.apple.product-type.application"; }};')

# Build configurations (target level)
settings = {
    'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
    'CODE_SIGN_STYLE': 'Automatic',
    'CURRENT_PROJECT_VERSION': '1',
    'GENERATE_INFOPLIST_FILE': 'NO',
    'INFOPLIST_FILE': 'ReaderApp/Info.plist',
    'IPHONEOS_DEPLOYMENT_TARGET': '16.0',
    'MARKETING_VERSION': '1.0.0',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.gogo564.reader',
    'PRODUCT_NAME': 'ReaderApp',
    'SWIFT_VERSION': '5.0',
    'TARGETED_DEVICE_FAMILY': '"1,2"',
}
settings_str = '{ ' + '; '.join(f'{k} = {v}' for k, v in settings.items()) + '; }'
lines.append(f'\t\t{debug_config} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {settings_str}; name = Debug; }};')
lines.append(f'\t\t{release_config} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {settings_str}; name = Release; }};')
lines.append(f'\t\t{target_config_list} = {{isa = XCConfigurationList; buildConfigurations = ( {debug_config}, {release_config} ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')

# Project
project_settings_debug = '{ ' + '; '.join([
    'ALWAYS_SEARCH_USER_PATHS = NO',
    'CLANG_ANALYZER_NONNULL = YES',
    'CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x"',
    'CLANG_ENABLE_MODULES = YES',
    'CLANG_ENABLE_OBJC_ARC = YES',
    'COPY_PHASE_STRIP = NO',
    'DEBUG_INFORMATION_FORMAT = dwarf',
    'ENABLE_STRICT_OBJC_MSGSEND = YES',
    'ENABLE_TESTABILITY = YES',
    'GCC_DYNAMIC_NO_PIC = NO',
    'GCC_OPTIMIZATION_LEVEL = 0',
    'GCC_PREPROCESSOR_DEFINITIONS = ( "DEBUG=1", "$(inherited)" )',
    'IPHONEOS_DEPLOYMENT_TARGET = 16.0',
    'MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE',
    'ONLY_ACTIVE_ARCH = YES',
    'SDKROOT = iphoneos',
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG',
    'SWIFT_OPTIMIZATION_LEVEL = "-Onone"',
]) + '; }'
project_settings_release = '{ ' + '; '.join([
    'ALWAYS_SEARCH_USER_PATHS = NO',
    'CLANG_ANALYZER_NONNULL = YES',
    'CLANG_CXX_LANGUAGE_STANDARD = "gnu++0x"',
    'CLANG_ENABLE_MODULES = YES',
    'CLANG_ENABLE_OBJC_ARC = YES',
    'COPY_PHASE_STRIP = NO',
    'DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym"',
    'ENABLE_NS_ASSERTIONS = NO',
    'ENABLE_STRICT_OBJC_MSGSEND = YES',
    'GCC_OPTIMIZATION_LEVEL = s',
    'IPHONEOS_DEPLOYMENT_TARGET = 16.0',
    'MTL_ENABLE_DEBUG_INFO = NO',
    'SDKROOT = iphoneos',
    'SWIFT_COMPILATION_MODE = wholemodule',
    'SWIFT_OPTIMIZATION_LEVEL = "-O"',
    'VALIDATE_PRODUCT = YES',
]) + '; }'

lines.append(f'\t\t{project_debug_config} /* Debug */ = {{isa = XCBuildConfiguration; buildSettings = {project_settings_debug}; name = Debug; }};')
lines.append(f'\t\t{project_release_config} /* Release */ = {{isa = XCBuildConfiguration; buildSettings = {project_settings_release}; name = Release; }};')
lines.append(f'\t\t{project_config_list} = {{isa = XCConfigurationList; buildConfigurations = ( {project_debug_config}, {project_release_config} ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')

# Project object
lines.append(f'\t\t{project_id} /* Project object */ = {{isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = 1; LastSwiftUpdateComment = 1; LastUpgradeCheck = 1; }}; buildConfigurationList = {project_config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = ( en, Base, ); mainGroup = {root_group}; productRefGroup = {product_group}; projectDirPath = ""; projectRoot = ""; targets = ( {target_id} ); }};')

lines.append('\t};')
lines.append(f'\trootObject = {project_id} /* Project object */;')
lines.append('}')

content = '\n'.join(lines) + '\n'

os.makedirs('ReaderApp.xcodeproj', exist_ok=True)
with open('ReaderApp.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)
print('Generated ReaderApp.xcodeproj/project.pbxproj')
