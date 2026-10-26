// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "acro_workspace", platforms: [.iOS("15.0")],
  products: [.library(name: "acro-workspace", targets: ["acro_workspace"])],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .binaryTarget(name: "AcroTLS", path: "Frameworks/AcroTLS.xcframework"),
    .binaryTarget(name: "avcodec", path: "Frameworks/avcodec.xcframework"),
    .binaryTarget(name: "avformat", path: "Frameworks/avformat.xcframework"),
    .binaryTarget(name: "avutil", path: "Frameworks/avutil.xcframework"),
    .binaryTarget(name: "SDL2", path: "Frameworks/SDL2.xcframework"),
    .binaryTarget(name: "opus", path: "Frameworks/opus.xcframework"),
    .target(name: "MoonlightCore", dependencies: ["AcroTLS"],
      sources: ["src", "enet/callbacks.c", "enet/compress.c", "enet/host.c", "enet/list.c", "enet/packet.c", "enet/peer.c", "enet/protocol.c", "enet/unix.c", "nanors/rs.c", "nanors/deps/obl/oblas_common.c", "nanors/deps/obl/oblas_lite.c"],
      publicHeadersPath: "include",
      cSettings: [.headerSearchPath("../../NativeHeaders/OpenSSL"), .headerSearchPath("src"), .headerSearchPath("enet/include"), .headerSearchPath("nanors"), .headerSearchPath("nanors/deps"), .headerSearchPath("nanors/deps/obl"),
        .define("HAS_SOCKLEN_T"), .define("HAS_FCNTL"), .define("HAS_IOCTL"), .define("HAS_POLL"), .define("HAS_GETADDRINFO"), .define("HAS_GETNAMEINFO"), .define("HAS_INET_PTON"), .define("HAS_INET_NTOP"), .define("HAS_MSGHDR_FLAGS")]),
    .target(name: "acro_workspace", dependencies: ["MoonlightCore", "avcodec", "avformat", "avutil", "SDL2", "opus",
        .product(name: "FlutterFramework", package: "FlutterFramework"), "AcroTLS"],
      publicHeadersPath: "include", cSettings: [.unsafeFlags(["-fobjc-arc"]), .headerSearchPath("../../NativeHeaders/OpenSSL"), .headerSearchPath("."), .headerSearchPath("../../NativeHeaders/opus/opus"), .headerSearchPath("../../NativeHeaders/SDL2"), .headerSearchPath("../../NativeHeaders/SDL2/SDL2"), .headerSearchPath("../../NativeHeaders/FFmpeg")],
      linkerSettings: [.linkedFramework("UIKit"), .linkedFramework("AVFoundation"), .linkedFramework("VideoToolbox"), .linkedFramework("AudioToolbox"), .linkedFramework("Security"), .linkedFramework("CFNetwork"), .linkedFramework("GameController"), .linkedFramework("CoreMotion"), .linkedFramework("CoreHaptics"), .linkedLibrary("xml2"), .linkedLibrary("z"), .linkedLibrary("bz2"), .linkedLibrary("iconv")])
  ], cLanguageStandard: .c11)
