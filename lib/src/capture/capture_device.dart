/// Metadata returned by the native camera; this is not measured frame rate.
class CaptureFormat {
  const CaptureFormat({
    required this.width,
    required this.height,
    required this.cameraName,
  });

  final int width;
  final int height;
  final String cameraName;
}

class CaptureFailure implements Exception {
  const CaptureFailure(this.code, this.message);

  final String code;
  final String message;
}

/// Exactly one owner may open a physical camera on this device.
/// Preview widgets borrow its output; they never open or close the device.
abstract interface class CaptureDevice {
  Future<CaptureFormat> open();
  Future<void> close();
}
