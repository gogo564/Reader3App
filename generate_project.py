#!/usr/bin/env python3
"""Generate DZMeBookRead.xcodeproj/project.pbxproj for Reader3App."""

import os, hashlib

PROJECT = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(PROJECT, "Reader3App")
DZM_DIR = os.path.join(APP_DIR, "DZMeBookRead")

def make_id(name):
    h = hashlib.md5(name.encode()).hexdigest()[:24].upper()
    return h

def collect_files():
    groups = {}
    for root, dirs, files in os.walk(DZM_DIR):
        rel = os.path.relpath(root, DZM_DIR)
        if rel == ".":
            grp_key = "DZMeBookRead"
        else:
            grp_key = "DZMeBookRead/" + rel
        entries = []
        for f in sorted(files):
            ext = os.path.splitext(f)[1].lower()
            if ext in ('.swift', '.h', '.m', '.mm', '.c', '.cpp', '.png', '.txt', '.bundle'):
                entries.append(f)
        if entries:
            groups[grp_key] = entries
    top_entries = []
    for f in sorted(os.listdir(APP_DIR)):
        fp = os.path.join(APP_DIR, f)
        if os.path.isfile(fp):
            ext = os.path.splitext(f)[1].lower()
            if ext in ('.swift', '.plist', '.storyboard'):
                top_entries.append(f)
    if top_entries:
        groups[""] = top_entries
    svc_entries = []
    svc_dir = os.path.join(APP_DIR, "Services")
    if os.path.isdir(svc_dir):
        for f in sorted(os.listdir(svc_dir)):
            if f.endswith('.swift'):
                svc_entries.append(f)
    if svc_entries:
        groups["Services"] = svc_entries
    return groups

def parent_key(k):
    if "/" not in k:
        return ""
    return k.rsplit("/", 1)[0]

def basename_key(k):
    return k.rsplit("/", 1)[-1] if "/" in k else k

def group_path(k):
    """Return the relative path from the project root to the group."""
    if k == "":
        return ""  # root group, no path
    if k == "DZMeBookRead":
        return "Reader3App/DZMeBookRead"
    if k.startswith("DZMeBookRead/"):
        sub = k[len("DZMeBookRead/"):]
        return f"Reader3App/DZMeBookRead/{sub}"
    if k == "Services":
        return "Reader3App/Services"
    # top-level Reader3App files use Reader3App/ prefix
    return f"Reader3App/{k}"

def rel_path(k, parent_k):
    """Return the path relative to parent group."""
    full = group_path(k)
    parent_full = group_path(parent_k)
    if parent_full and full.startswith(parent_full + "/"):
        return full[len(parent_full) + 1:]
    return basename_key(k)

def gen_pbxproj():
    groups = collect_files()

    all_files = []
    source_exts = {'.swift', '.m', '.mm', '.c', '.cpp'}
    type_map = {
        '.swift': 'sourcecode.swift',
        '.h': 'sourcecode.c.h',
        '.m': 'sourcecode.c.objc',
        '.mm': 'sourcecode.cpp.objcpp',
        '.c': 'sourcecode.c.c',
        '.cpp': 'sourcecode.cpp.cpp',
        '.png': 'image.png',
        '.txt': 'text',
        '.bundle': 'wrapper.plug-in',
        '.storyboard': 'file.storyboard',
        '.plist': 'text.plist.xml',
    }

    for grp_key, fnames in groups.items():
        if grp_key == "DZMeBookRead":
            base = DZM_DIR
        elif grp_key.startswith("DZMeBookRead/"):
            base = os.path.join(DZM_DIR, grp_key[len("DZMeBookRead/"):])
        elif grp_key == "":
            base = APP_DIR
        else:
            base = os.path.join(APP_DIR, grp_key)
        for fn in fnames:
            fp = os.path.join(base, fn)
            ext = os.path.splitext(fn)[1].lower()
            all_files.append((grp_key, fn, fp, ext in source_exts))

    build_ids = {}
    ref_ids = {}
    for grp_key, fn, fp, _ in all_files:
        uid = f"file::{grp_key}/{fn}"
        ref_ids[(grp_key, fn)] = make_id(uid)
        build_ids[(grp_key, fn)] = make_id(uid + "::build")

    all_grp_keys = set()
    for grp_key, _, _, _ in all_files:
        parts = grp_key.split("/") if grp_key else []
        for i in range(len(parts)):
            all_grp_keys.add("/".join(parts[:i+1]))
        all_grp_keys.add("")

    group_ids = {k: make_id(f"group:::{k}") for k in sorted(all_grp_keys)}

    root_group_id = group_ids[""]

    # IDs
    product_ref_id = make_id("PBXFileReference::app")
    sources_phase_id = make_id("PBXSourcesBuildPhase::main")
    resources_phase_id = make_id("PBXResourcesBuildPhase::main")
    frameworks_phase_id = make_id("PBXFrameworksBuildPhase::main")
    assets_ref_id = make_id("ref::Assets.xcassets")
    assets_build_id = make_id("res::Assets.xcassets")
    main_target_id = make_id("PBXNativeTarget::main")
    project_id = make_id("PBXProject::project")
    products_group_id = make_id("PBXGroup::Products")

    project_build_config_list_id = make_id("XCBuildConfigurationList::project")
    debug_config_id = make_id("XCBuildConfiguration::Debug")
    release_config_id = make_id("XCBuildConfiguration::Release")
    target_build_config_list_id = make_id("XCBuildConfigurationList::target")
    target_debug_config_id = make_id("XCBuildConfiguration::target::Debug")
    target_release_config_id = make_id("XCBuildConfiguration::target::Release")

    lines = []
    def L(s=""):
        lines.append(s)

    L("// !$*UTF8*$!")
    L("{")
    L("\tarchiveVersion = 1;")
    L("\tclasses = {")
    L("\t};")
    L("\tobjectVersion = 56;")
    L("\tobjects = {")

    # === PBXBuildFile ===
    L()
    L("/* Begin PBXBuildFile section */")
    for grp_key, fn, fp, is_source in all_files:
        if is_source:
            fid = build_ids[(grp_key, fn)]
            rid = ref_ids[(grp_key, fn)]
            L(f"\t\t{fid} /* {fn} in Sources */ = {{isa = PBXBuildFile; fileRef = {rid}; }};")
    L(f"\t\t{assets_build_id} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref_id}; }};")
    L("/* End PBXBuildFile section */")

    # === PBXFileReference ===
    L()
    L("/* Begin PBXFileReference section */")
    L(f"\t\t{product_ref_id} /* Reader3App.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Reader3App.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    L(f"\t\t{assets_ref_id} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Reader3App/Assets.xcassets; sourceTree = SOURCE_ROOT; }};")
    L(f"\t\t{make_id('ref::Info.plist')} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Reader3App/Info.plist; sourceTree = SOURCE_ROOT; }};")
    for grp_key, fn, fp, is_source in all_files:
        fid = ref_ids[(grp_key, fn)]
        ext = os.path.splitext(fn)[1].lower()
        file_type = type_map.get(ext, 'text')
        L(f"\t\t{fid} /* {fn} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; name = \"{fn}\"; path = \"{fn}\"; sourceTree = \"<group>\"; }};")
    L("/* End PBXFileReference section */")

    # === PBXGroup ===
    L()
    L("/* Begin PBXGroup section */")

    # Root group
    L(f"\t\t{root_group_id} = {{")
    L("\t\t\tisa = PBXGroup;")
    L("\t\t\tchildren = (")
    L(f"\t\t\t\t{products_group_id} /* Products */,")
    main_app_group_id = make_id("group:::Reader3App")
    L(f"\t\t\t\t{main_app_group_id} /* Reader3App */,")
    L("\t\t\t);")
    L('\t\t\tname = "Reader3App";')
    L("\t\t\tsourceTree = \"<group>\";")
    L("\t\t};")

    # Products
    L()
    L(f"\t\t{products_group_id} = {{")
    L("\t\t\tisa = PBXGroup;")
    L("\t\t\tchildren = (")
    L(f"\t\t\t\t{product_ref_id} /* Reader3App.app */,")
    L("\t\t\t);")
    L("\t\t\tname = Products;")
    L("\t\t\tsourceTree = \"<group>\";")
    L("\t\t};")

    # Main app group
    L()
    L(f"\t\t{main_app_group_id} = {{")
    L("\t\t\tisa = PBXGroup;")
    L("\t\t\tchildren = (")
    # Info.plist and Assets.xcassets first
    L(f"\t\t\t\t{make_id('ref::Info.plist')} /* Info.plist */,")
    L(f"\t\t\t\t{assets_ref_id} /* Assets.xcassets */,")
    # Then top-level Swift files
    for grp_key, fn, fp, _ in all_files:
        if grp_key == "" and fn.endswith('.swift'):
            L(f"\t\t\t\t{ref_ids[(grp_key, fn)]} /* {fn} */,")
    # Then sub-groups sorted by name
    sub_grps = sorted([k for k in all_grp_keys if parent_key(k) == "" and k != "" and k != "DZMeBookRead"])
    if "Services" in sub_grps:
        L(f"\t\t\t\t{group_ids['Services']} /* Services */,")
    if "DZMeBookRead" in all_grp_keys:
        L(f"\t\t\t\t{group_ids['DZMeBookRead']} /* DZMeBookRead */,")
    L("\t\t\t);")
    L("\t\t\tpath = Reader3App;")
    L("\t\t\tsourceTree = \"<group>\";")
    L("\t\t};")

    # Services group
    if "Services" in group_ids:
        L()
        L(f"\t\t{group_ids['Services']} = {{")
        L("\t\t\tisa = PBXGroup;")
        L("\t\t\tchildren = (")
        for grp_key, fn, fp, _ in all_files:
            if grp_key == "Services":
                L(f"\t\t\t\t{ref_ids[(grp_key, fn)]} /* {fn} */,")
        L("\t\t\t);")
        L("\t\t\tpath = Services;")
        L("\t\t\tsourceTree = \"<group>\";")
        L("\t\t};")

    # DZMeBookRead group and sub-groups
    dzm_groups = sorted([k for k in all_grp_keys if k.startswith("DZMeBookRead") or k == "DZMeBookRead"])
    for gk in dzm_groups:
        gid = group_ids[gk]
        children = []
        for sgk in sorted(all_grp_keys):
            if parent_key(sgk) == gk:
                children.append(("group", group_ids[sgk], basename_key(sgk)))
        for grp_key, fn, fp, _ in all_files:
            if grp_key == gk:
                children.append(("file", ref_ids[(grp_key, fn)], fn))
        # Skip if no children (unlikely but safe)
        if not children:
            continue
        L()
        L(f"\t\t{gid} = {{")
        L("\t\t\tisa = PBXGroup;")
        L("\t\t\tchildren = (")
        for ctype, cid, cname in sorted(children, key=lambda x: x[2]):
            L(f"\t\t\t\t{cid} /* {cname} */,")
        L("\t\t\t);")
        # Path relative to parent
        if gk == "DZMeBookRead":
            L('\t\t\tpath = "DZMeBookRead";')
        else:
            p = parent_key(gk)
            r = rel_path(gk, p)
            L(f'\t\t\tpath = "{r}";')
        L("\t\t\tsourceTree = \"<group>\";")
        L("\t\t};")

    L("/* End PBXGroup section */")

    # === PBXNativeTarget ===
    L()
    L("/* Begin PBXNativeTarget section */")
    L(f"\t\t{main_target_id} /* Reader3App */ = {{")
    L("\t\t\tisa = PBXNativeTarget;")
    L(f"\t\t\tbuildConfigurationList = {target_build_config_list_id} /* Build configuration list for PBXNativeTarget \"Reader3App\" */;")
    L("\t\t\tbuildPhases = (")
    L(f"\t\t\t\t{sources_phase_id} /* Sources */,")
    L(f"\t\t\t\t{frameworks_phase_id} /* Frameworks */,")
    L(f"\t\t\t\t{resources_phase_id} /* Resources */,")
    L("\t\t\t);")
    L("\t\t\tbuildRules = (")
    L("\t\t\t);")
    L("\t\t\tdependencies = (")
    L("\t\t\t);")
    L("\t\t\tname = Reader3App;")
    L("\t\t\tproductName = Reader3App;")
    L(f"\t\t\tproductReference = {product_ref_id};")
    L('\t\t\tproductType = "com.apple.product-type.application";')
    L("\t\t};")
    L("/* End PBXNativeTarget section */")

    # === PBXProject ===
    L()
    L("/* Begin PBXProject section */")
    L(f"\t\t{project_id} /* Project object */ = {{")
    L("\t\t\tisa = PBXProject;")
    L("\t\t\tattributes = {")
    L(f'\t\t\t\tLastSwiftUpdateCheck = 1500;')
    L(f'\t\t\t\tLastUpgradeCheck = 1500;')
    L("\t\t\t\tTargetAttributes = {")
    L(f"\t\t\t\t\t{main_target_id} = {{")
    L("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    L("\t\t\t\t\t};")
    L("\t\t\t\t};")
    L("\t\t\t};")
    L(f"\t\t\tbuildConfigurationList = {project_build_config_list_id} /* Build configuration list for PBXProject \"Reader3App\" */;")
    L('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    L("\t\t\tdevelopmentRegion = en;")
    L("\t\t\thasScannedForEncodings = 0;")
    L("\t\t\tknownRegions = (")
    L("\t\t\t\ten,")
    L("\t\t\t\tBase,")
    L("\t\t\t);")
    L(f"\t\t\tmainGroup = {root_group_id};")
    L(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    L('\t\t\tprojectDirPath = "";')
    L('\t\t\tprojectRoot = "";')
    L("\t\t\ttargets = (")
    L(f"\t\t\t\t{main_target_id} /* Reader3App */,")
    L("\t\t\t);")
    L("\t\t};")
    L("/* End PBXProject section */")

    # === PBXSourcesBuildPhase ===
    L()
    L("/* Begin PBXSourcesBuildPhase section */")
    L(f"\t\t{sources_phase_id} /* Sources */ = {{")
    L("\t\t\tisa = PBXSourcesBuildPhase;")
    L("\t\t\tbuildActionMask = 2147483647;")
    L("\t\t\tfiles = (")
    for grp_key, fn, fp, is_source in all_files:
        if is_source:
            fid = build_ids[(grp_key, fn)]
            L(f"\t\t\t\t{fid} /* {fn} in Sources */,")
    L("\t\t\t);")
    L("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L("\t\t};")
    L("/* End PBXSourcesBuildPhase section */")

    # === PBXResourcesBuildPhase ===
    L()
    L("/* Begin PBXResourcesBuildPhase section */")
    L(f"\t\t{resources_phase_id} /* Resources */ = {{")
    L("\t\t\tisa = PBXResourcesBuildPhase;")
    L("\t\t\tbuildActionMask = 2147483647;")
    L("\t\t\tfiles = (")
    L(f"\t\t\t\t{assets_build_id} /* Assets.xcassets in Resources */,")
    L("\t\t\t);")
    L("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L("\t\t};")
    L("/* End PBXResourcesBuildPhase section */")

    # === PBXFrameworksBuildPhase ===
    L()
    L("/* Begin PBXFrameworksBuildPhase section */")
    L(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
    L("\t\t\tisa = PBXFrameworksBuildPhase;")
    L("\t\t\tbuildActionMask = 2147483647;")
    L("\t\t\tfiles = (")
    L("\t\t\t);")
    L("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L("\t\t};")
    L("/* End PBXFrameworksBuildPhase section */")

    # === XCBuildConfiguration ===
    L()
    L("/* Begin XCBuildConfiguration section */")
    L(f"\t\t{debug_config_id} /* Debug */ = {{")
    L("\t\t\tisa = XCBuildConfiguration;")
    L("\t\t\tbuildSettings = {")
    L('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
    L('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
    L('\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++14";')
    L('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
    L('\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;')
    L('\t\t\t\tCOPY_PHASE_STRIP = NO;')
    L('\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;')
    L('\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;')
    L('\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");')
    L('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;')
    L('\t\t\t\tMTL_ENABLE_DEBUG_INFO = YES;')
    L('\t\t\t\tONLY_ACTIVE_ARCH = YES;')
    L('\t\t\t\tSDKROOT = iphoneos;')
    L('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;')
    L('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
    L("\t\t\t};")
    L("\t\t\tname = Debug;")
    L("\t\t};")
    L()
    L(f"\t\t{release_config_id} /* Release */ = {{")
    L("\t\t\tisa = XCBuildConfiguration;")
    L("\t\t\tbuildSettings = {")
    L('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
    L('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
    L('\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++14";')
    L('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
    L('\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;')
    L('\t\t\t\tCOPY_PHASE_STRIP = NO;')
    L('\t\t\t\tENABLE_NS_ASSERTIONS = NO;')
    L('\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;')
    L('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;')
    L('\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;')
    L('\t\t\t\tSDKROOT = iphoneos;')
    L('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";')
    L('\t\t\t\tVALIDATE_PRODUCT = YES;')
    L("\t\t\t};")
    L("\t\t\tname = Release;")
    L("\t\t};")
    L()
    L(f"\t\t{target_debug_config_id} /* Debug */ = {{")
    L("\t\t\tisa = XCBuildConfiguration;")
    L("\t\t\tbuildSettings = {")
    L('\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
    L('\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";')
    L('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
    L('\t\t\t\tINFOPLIST_FILE = "Reader3App/Info.plist";')
    L('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;')
    L('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";')
    L('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.reader3.app;')
    L('\t\t\t\tPRODUCT_NAME = Reader3App;')
    L('\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";')
    L('\t\t\t\tSWIFT_VERSION = 5.0;')
    L('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
    L("\t\t\t};")
    L("\t\t\tname = Debug;")
    L("\t\t};")
    L()
    L(f"\t\t{target_release_config_id} /* Release */ = {{")
    L("\t\t\tisa = XCBuildConfiguration;")
    L("\t\t\tbuildSettings = {")
    L('\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
    L('\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";')
    L('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
    L('\t\t\t\tINFOPLIST_FILE = "Reader3App/Info.plist";')
    L('\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;')
    L('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";')
    L('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.reader3.app;')
    L('\t\t\t\tPRODUCT_NAME = Reader3App;')
    L('\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";')
    L('\t\t\t\tSWIFT_VERSION = 5.0;')
    L('\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";')
    L("\t\t\t};")
    L("\t\t\tname = Release;")
    L("\t\t};")
    L("/* End XCBuildConfiguration section */")

    # === XCBuildConfigurationList ===
    L()
    L("/* Begin XCBuildConfigurationList section */")
    L(f"\t\t{project_build_config_list_id} /* Build configuration list for PBXProject \"Reader3App\" */ = {{")
    L("\t\t\tisa = XCBuildConfigurationList;")
    L("\t\t\tbuildConfigurations = (")
    L(f"\t\t\t\t{debug_config_id} /* Debug */,")
    L(f"\t\t\t\t{release_config_id} /* Release */,")
    L("\t\t\t);")
    L("\t\t\tdefaultConfigurationIsVisible = 0;")
    L("\t\t\tdefaultConfigurationName = Release;")
    L("\t\t};")
    L()
    L(f"\t\t{target_build_config_list_id} /* Build configuration list for PBXNativeTarget \"Reader3App\" */ = {{")
    L("\t\t\tisa = XCBuildConfigurationList;")
    L("\t\t\tbuildConfigurations = (")
    L(f"\t\t\t\t{target_debug_config_id} /* Debug */,")
    L(f"\t\t\t\t{target_release_config_id} /* Release */,")
    L("\t\t\t);")
    L("\t\t\tdefaultConfigurationIsVisible = 0;")
    L("\t\t\tdefaultConfigurationName = Release;")
    L("\t\t};")
    L("/* End XCBuildConfigurationList section */")

    L("};")
    L("}")

    return "\n".join(lines)

if __name__ == "__main__":
    pbx = gen_pbxproj()
    xcodeproj = os.path.join(PROJECT, "DZMeBookRead.xcodeproj")
    os.makedirs(xcodeproj, exist_ok=True)
    out = os.path.join(xcodeproj, "project.pbxproj")
    with open(out, "w") as f:
        f.write(pbx)
    print(f"Generated {out}")
    print(f"File size: {os.path.getsize(out)} bytes")
