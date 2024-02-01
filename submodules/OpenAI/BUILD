load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Define the Swift library
swift_library(
    name = "OpenAI",
    module_name = "OpenAI",
    srcs = glob(["Sources/**/*.swift"]),
    deps = [
        "//submodules/AIStrings:AIStrings",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/RevenueCat:RevenueCat"
    ],
    visibility = ["//visibility:public"],
)
