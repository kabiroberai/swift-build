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

#ifndef SWB_MACHO_COMPATIBILITY_H
#define SWB_MACHO_COMPATIBILITY_H

// These are the on-disk layouts from mach-o/fat.h, mach-o/loader.h, and ar.h.
// They let the reader inspect Apple binaries on hosts without Darwin headers.
#if !defined(__APPLE__)

#include <stdint.h>

typedef int32_t cpu_type_t;
typedef int32_t cpu_subtype_t;
typedef int32_t vm_prot_t;

#define CPU_TYPE_ANY (-1)
#define CPU_ARCH_ABI64 0x01000000
#define CPU_TYPE_X86 7
#define CPU_TYPE_I386 CPU_TYPE_X86
#define CPU_TYPE_X86_64 (CPU_TYPE_X86 | CPU_ARCH_ABI64)
#define CPU_TYPE_ARM 12
#define CPU_TYPE_ARM64 (CPU_TYPE_ARM | CPU_ARCH_ABI64)

#define FAT_MAGIC 0xcafebabe
#define FAT_CIGAM 0xbebafeca
#define FAT_MAGIC_64 0xcafebabf
#define FAT_CIGAM_64 0xbfbafeca
#define MH_MAGIC 0xfeedface
#define MH_CIGAM 0xcefaedfe
#define MH_MAGIC_64 0xfeedfacf
#define MH_CIGAM_64 0xcffaedfe
#define MH_OBJECT 1
#define MH_EXECUTE 2
#define MH_DYLIB 6
#define MH_BUNDLE 8

#define LC_SEGMENT 0x1
#define LC_SYMTAB 0x2
#define LC_LOAD_DYLIB 0xc
#define LC_ID_DYLIB 0xd
#define LC_LOAD_WEAK_DYLIB 0x80000018
#define LC_SEGMENT_64 0x19
#define LC_UUID 0x1b
#define LC_RPATH 0x8000001c
#define LC_REEXPORT_DYLIB 0x8000001f
#define LC_LAZY_LOAD_DYLIB 0x20
#define LC_LOAD_UPWARD_DYLIB 0x80000023
#define LC_VERSION_MIN_MACOSX 0x24
#define LC_VERSION_MIN_IPHONEOS 0x25
#define LC_MAIN 0x80000028
#define LC_VERSION_MIN_TVOS 0x2f
#define LC_VERSION_MIN_WATCHOS 0x30
#define LC_BUILD_VERSION 0x32
#define LC_ATOM_INFO 0x36

struct fat_header { uint32_t magic, nfat_arch; };
struct fat_arch {
  cpu_type_t cputype;
  cpu_subtype_t cpusubtype;
  uint32_t offset, size, align;
};
struct fat_arch_64 {
  cpu_type_t cputype;
  cpu_subtype_t cpusubtype;
  uint64_t offset, size;
  uint32_t align, reserved;
};
struct mach_header {
  uint32_t magic;
  cpu_type_t cputype;
  cpu_subtype_t cpusubtype;
  uint32_t filetype, ncmds, sizeofcmds, flags;
};
struct mach_header_64 {
  uint32_t magic;
  cpu_type_t cputype;
  cpu_subtype_t cpusubtype;
  uint32_t filetype, ncmds, sizeofcmds, flags, reserved;
};
struct load_command { uint32_t cmd, cmdsize; };
union lc_str { uint32_t offset; };
struct dylib {
  union lc_str name;
  uint32_t timestamp, current_version, compatibility_version;
};
struct dylib_command { uint32_t cmd, cmdsize; struct dylib dylib; };
struct uuid_command { uint32_t cmd, cmdsize; uint8_t uuid[16]; };
struct segment_command {
  uint32_t cmd, cmdsize;
  char segname[16];
  uint32_t vmaddr, vmsize, fileoff, filesize;
  vm_prot_t maxprot, initprot;
  uint32_t nsects, flags;
};
struct segment_command_64 {
  uint32_t cmd, cmdsize;
  char segname[16];
  uint64_t vmaddr, vmsize, fileoff, filesize;
  vm_prot_t maxprot, initprot;
  uint32_t nsects, flags;
};
struct section {
  char sectname[16], segname[16];
  uint32_t addr, size, offset, align, reloff, nreloc, flags, reserved1, reserved2;
};
struct section_64 {
  char sectname[16], segname[16];
  uint64_t addr, size;
  uint32_t offset, align, reloff, nreloc, flags, reserved1, reserved2, reserved3;
};
struct build_version_command { uint32_t cmd, cmdsize, platform, minos, sdk, ntools; };
struct version_min_command { uint32_t cmd, cmdsize, version, sdk; };
struct rpath_command { uint32_t cmd, cmdsize; union lc_str path; };

#define SARMAG 8
#define AR_EFMT1 "#1/"
struct ar_hdr {
  char ar_name[16], ar_date[12], ar_uid[6], ar_gid[6];
  char ar_mode[8], ar_size[10], ar_fmag[2];
};

#endif // !defined(__APPLE__)
#endif // SWB_MACHO_COMPATIBILITY_H
