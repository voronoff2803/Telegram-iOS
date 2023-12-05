load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "InvisibleInkDustMetalSources",
    srcs = glob([
        "Metal/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "InvisibleInkDustMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.InvisibleInkDustMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>InvisibleInkDustMetal</string>
    """
)

apple_resource_bundle(
    name = "InvisibleInkDustMetalSourcesBundle",
    infoplists = [
        ":InvisibleInkDustMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":InvisibleInkDustMetalSources",
    ],
)

swift_library(
    name = "InvisibleInkDustNode",
    module_name = "InvisibleInkDustNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":InvisibleInkDustMetalSourcesBundle",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AppBundle:AppBundle",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/MetalEngine:MetalEngine",
    ],
    visibility = [
        "//visibility:public",
    ],
)
