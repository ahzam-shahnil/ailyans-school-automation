import 'package:flutter_test/flutter_test.dart';
import 'package:school_automation/widgets/camera_capture_dialog.dart';

void main() {
  group('formatCameraLabel (Camera Label Sanitization)', () {
    test('1. Strips Windows USB device path (<\\\\?\\usb#...>) from camera name', () {
      const rawName =
          r'Lenovo EasyCamera <\\?\usb#vid_5986&pid_0296&mi_00#7&21f6b15&0&0000#{e5323777-f977-4f0b-bc10-3909e81cb3d0}\global>';
      final formatted = formatCameraLabel(rawName, 0);
      expect(formatted, equals('Lenovo EasyCamera'));
    });

    test('2. Strips any suffix beginning with " <"', () {
      const rawName = r'Logitech Webcam <device_id_12345>';
      expect(formatCameraLabel(rawName, 0), equals('Logitech Webcam'));
      expect(CameraCaptureDialog.formatCameraLabel(rawName, 0), equals('Logitech Webcam'));
    });

    test('3. Returns clean names untouched if no device path is attached', () {
      expect(formatCameraLabel('FaceTime HD Camera', 0), equals('FaceTime HD Camera'));
      expect(formatCameraLabel('Integrated Webcam', 1), equals('Integrated Webcam'));
    });

    test('4. Falls back to "Camera {index + 1}" when raw name is empty or whitespace', () {
      expect(formatCameraLabel('', 0), equals('Camera 1'));
      expect(formatCameraLabel('   ', 1), equals('Camera 2'));
      expect(formatCameraLabel('\t\n', 2), equals('Camera 3'));
    });

    test('5. Falls back to "Camera {index + 1}" when raw name contains only the path bracket', () {
      const onlyBracket = r'<\\?\usb#vid_5986&pid_0296&mi_00#...>';
      expect(formatCameraLabel(onlyBracket, 0), equals('Camera 1'));

      const spaceAndBracket = r' <\\?\usb#vid_5986&pid_0296&mi_00#...>';
      expect(formatCameraLabel(spaceAndBracket, 1), equals('Camera 2'));
    });
  });
}
