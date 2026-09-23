//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import Testing
@_spi(Testing) import SWBUtil

@Suite
fileprivate struct MachOPortableTests {
    private func append(_ value: UInt32, to bytes: inout [UInt8], bigEndian: Bool = false) {
        let value = bigEndian ? value.bigEndian : value.littleEndian
        withUnsafeBytes(of: value) { bytes.append(contentsOf: $0) }
    }

    private func thinMachO() -> [UInt8] {
        var commands: [UInt8] = []
        append(0x32, to: &commands) // LC_BUILD_VERSION
        append(24, to: &commands)
        append(2, to: &commands) // iOS
        append(0x0011_0000, to: &commands) // 17.0
        append(0x0012_0000, to: &commands) // 18.0
        append(0, to: &commands)

        append(0x1b, to: &commands) // LC_UUID
        append(24, to: &commands)
        commands += (0..<16).map { UInt8($0) }

        let installName = Array("/usr/lib/libFixture.dylib".utf8) + [0]
        let dylibCommandSize = (24 + installName.count + 7) & ~7
        append(0xd, to: &commands) // LC_ID_DYLIB
        append(UInt32(dylibCommandSize), to: &commands)
        append(24, to: &commands) // name offset
        append(0, to: &commands) // timestamp
        append(0, to: &commands) // current version
        append(0, to: &commands) // compatibility version
        commands += installName
        commands += repeatElement(0, count: dylibCommandSize - 24 - installName.count)

        var bytes: [UInt8] = []
        append(0xfeed_facf, to: &bytes) // MH_MAGIC_64
        append(0x0100_000c, to: &bytes) // CPU_TYPE_ARM64
        append(0, to: &bytes) // CPU_SUBTYPE_ARM64_ALL
        append(6, to: &bytes) // MH_DYLIB
        append(3, to: &bytes)
        append(UInt32(commands.count), to: &bytes)
        append(0, to: &bytes)
        append(0, to: &bytes)
        return bytes + commands
    }

    @Test
    func thinSlice() throws {
        let macho = try MachO(data: ByteString(thinMachO()))
        let slices = try macho.slices()
        let slice = try #require(slices.only)
        #expect(slice.arch == "arm64")
        #expect(slice.linkFileType == .macho(.dylib))
        let buildVersion = try #require(slice.buildVersions().only)
        #expect(buildVersion.platform == .iOS)
        #expect(buildVersion.minOSVersion == Version(17))
        #expect(buildVersion.sdkVersion == Version(18))
        #expect(try slice.installName() == "/usr/lib/libFixture.dylib")
        #expect(try slice.uuid() == UUID(uuid: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)))
    }

    @Test
    func fatSlice() throws {
        let thin = thinMachO()
        var bytes: [UInt8] = []
        append(0xcafe_babe, to: &bytes, bigEndian: true)
        append(1, to: &bytes, bigEndian: true)
        append(0x0100_000c, to: &bytes, bigEndian: true)
        append(0, to: &bytes, bigEndian: true)
        append(28, to: &bytes, bigEndian: true)
        append(UInt32(thin.count), to: &bytes, bigEndian: true)
        append(0, to: &bytes, bigEndian: true)
        bytes += thin

        let macho = try MachO(data: ByteString(bytes))
        #expect(try macho.slices().map(\.arch) == ["arm64"])
    }

    @Test
    func staticArchive() throws {
        let thin = thinMachO()
        var bytes = Array("!<arch>\n".utf8)
        func field(_ text: String, width: Int) {
            let value = Array(text.utf8)
            bytes += value
            bytes += repeatElement(UInt8(ascii: " "), count: width - value.count)
        }
        field("fixture.o/", width: 16)
        field("0", width: 12)
        field("0", width: 6)
        field("0", width: 6)
        field("100644", width: 8)
        field(String(thin.count), width: 10)
        bytes += Array("`\n".utf8)
        bytes += thin
        if thin.count % 2 != 0 { bytes.append(10) }

        let macho = try MachO(data: ByteString(bytes))
        let result = try macho.slicesIncludingLinkage()
        #expect(result.linkage == .static)
        #expect(result.slices.map(\.arch) == ["arm64"])
    }
}
