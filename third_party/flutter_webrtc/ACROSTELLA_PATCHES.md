Upstream flutter_webrtc 1.6.2+hotfix.4, downloaded from pub.dev. Original MIT
license and notices retained. No bundled WebRTC binaries: standard upstream
Gradle/SPM dependencies are resolved when building.

AcroStella changes (native recording fan-out only):
- Android: a one-frame gate bounds retained video frames; source nanosecond
  timestamps go to EGL presentation instead of using render time.
- iOS: one retained frame on a serial writer queue, first-frame orientation in
  MP4 metadata, initialized sample timing, safe completion when no frames exist.
- Both: recordingInfo reports age of first accepted frame on a local monotonic
  clock and dropped recording frames. This is receipt/encoding telemetry, not
  a sensor exposure timestamp or a guarantee of perfect synchronization.

Camera capture, texture preview and WebRTC share the same native video track.
Raw frames never cross to Dart. Audit this diff before updating the vendored
package; do not replace the bounded sinks with the upstream unbounded queue.
