load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RevenueCatUI",
    module_name = "RevenueCatUI",
    srcs = glob(["Sources/**/*.swift"]),
    # Include dependencies of RevenueCat here
    deps = [
        "//submodules/RevenueCat:RevenueCat"
    ],
    visibility = ["//visibility:public"],
)