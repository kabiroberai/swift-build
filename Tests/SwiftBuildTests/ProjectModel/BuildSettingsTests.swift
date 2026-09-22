//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import SwiftBuild
import SWBUtil
import Testing

@Suite
fileprivate struct BuildSettingsTests {
    @Test func basicEncoding() throws {
        try testCodable(ProjectModel.BuildSettings.example)

        let obj = ProjectModel.BuildSettings()

        try testCodable(obj) { $0[.BUILT_PRODUCTS_DIR] = "/tmp" }
        try testCodable(obj) { $0[.HEADER_SEARCH_PATHS] = ["/foo", "/bar"] }
        try testCodable(obj) { $0.platformSpecificSettings[.macOS, default: [:]][.FRAMEWORK_SEARCH_PATHS] = ["/baz", "/qux"] }
        try testCodable(obj) { $0[.DYLIB_INSTALL_NAME_BASE, .macOS] = "@rpath" }
        try testCodable(obj) { $0[.CLANG_ENABLE_MODULES, .macOS] = "NO" }
        try testCodable(obj) { $0[.SWIFT_MODULE_ALIASES, .macOS] = ["A=B", "C=D"] }
        try testCodable(obj) { $0[single: "CUSTOM1"] = "value" }
        try testCodable(obj) { $0[multiple: "CUSTOM2"] = ["value1", "value2"] }
    }

    @Test func wasiPlatformFilters() {
        // For triples like `wasm32-unknown-wasip1-threads` the build-time filter carries the
        // environment and matching is exact on (platform, environment), so `.wasi` must cover
        // the environment-qualified variants alongside the environment-less ones.
        let filters = Set(ProjectModel.BuildSettings.Platform.wasi.toPlatformFilter())
        let expected: Set<ProjectModel.PlatformFilter> = [
            .init(platform: "wasi"),
            .init(platform: "wasip1"),
            .init(platform: "wasi", environment: "threads"),
            .init(platform: "wasip1", environment: "threads"),
        ]
        #expect(filters == expected)
    }

    @Test func unknownBuildSettings() throws {
        var obj = ProjectModel.BuildSettings()
        obj[single: "CUSTOM1"] = "value"
        obj[multiple: "CUSTOM2"] = ["foo", "bar"]

        let data = try JSONEncoder().encode(obj)
        let decoded = try #require(PropertyList.fromJSONData(data).dictValue)
        #expect(decoded["CUSTOM1"]?.stringValue == "value")
        #expect(decoded["CUSTOM2"]?.stringArrayValue == ["foo", "bar"])
    }

    @Test func decodingUnknownBuildSettings() throws {
        let data = Data(#"""
        {
            "PRODUCT_NAME": "App",
            "CUSTOM1": "value",
            "CUSTOM2": ["foo", "bar"],
            "CUSTOM3[__platform_filter=macos]": "mac",
            "CUSTOM4[__platform_filter=macos]": ["one", "two"],
            "ARCHS[__platform_filter=macos]": ["arm64"],
            "CLANG_ENABLE_MODULES[__platform_filter=macos]": "YES"
        }
        """#.utf8)
        let settings = try JSONDecoder().decode(ProjectModel.BuildSettings.self, from: data)

        #expect(settings[.PRODUCT_NAME] == "App")
        #expect(settings[single: "CUSTOM1"] == "value")
        #expect(settings[multiple: "CUSTOM2"] == ["foo", "bar"])
        #expect(settings[single: "CUSTOM3[__platform_filter=macos]"] == nil)
        #expect(settings[multiple: "CUSTOM4[__platform_filter=macos]"] == nil)
        #expect(settings[.CLANG_ENABLE_MODULES, .macOS] == "YES")
        #expect(settings[single: "CLANG_ENABLE_MODULES[__platform_filter=macos]"] == nil)
        #expect(settings.platformSpecificSettings[.macOS]?[.ARCHS] == ["arm64"])

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try #require(PropertyList.fromJSONData(encoded).dictValue)
        #expect(decoded["CUSTOM1"]?.stringValue == "value")
        #expect(decoded["CUSTOM2"]?.stringArrayValue == ["foo", "bar"])
        #expect(decoded["CUSTOM3[__platform_filter=macos]"]?.stringValue == "mac")
        #expect(decoded["CUSTOM4[__platform_filter=macos]"]?.stringArrayValue == ["one", "two"])
        #expect(decoded["ARCHS[__platform_filter=macos]"]?.stringArrayValue == ["arm64"])
    }
}

extension ProjectModel.BuildSettings {
    static var example: Self {
        var settings = ProjectModel.BuildSettings()
        settings[.CLANG_CXX_LANGUAGE_STANDARD] = "c++17"
        settings[.FRAMEWORK_SEARCH_PATHS] = ["/path1", "/path2"]
        settings.platformSpecificSettings[.linux, default: [:]][.HEADER_SEARCH_PATHS] = ["/foo", "/bar"]
        return settings
    }
}
