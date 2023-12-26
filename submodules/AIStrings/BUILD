load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Define the Swift library
swift_library(
    name = "AIStrings",
    module_name = "AIStrings",
    srcs = glob(["Sources/**/*.swift"]),
    deps = [
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = ["//visibility:public"],
)
