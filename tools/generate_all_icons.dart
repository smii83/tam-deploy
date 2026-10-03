// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final lightSourcePath = r'C:\Users\smiip\.gemini\antigravity-ide\brain\0d58c427-fd57-4908-a5f6-77b14ec322cb\.user_uploaded\media_1790358020091.jpg';
  final darkSourcePath = r'C:\Users\smiip\.gemini\antigravity-ide\brain\0d58c427-fd57-4908-a5f6-77b14ec322cb\.user_uploaded\media_1790358020169.png';

  final lightSrcBytes = File(lightSourcePath).readAsBytesSync();
  final darkSrcBytes = File(darkSourcePath).readAsBytesSync();

  final lightImg = img.decodeImage(lightSrcBytes)!;
  final darkImg = img.decodeImage(darkSrcBytes)!;

  print('Source Light: ${lightImg.width}x${lightImg.height}');
  print('Source Dark: ${darkImg.width}x${darkImg.height}');

  // 1. Transparent Light Logo for in-app widgets (TamLogoWidget)
  final lightTransparent = img.Image(
    width: lightImg.width,
    height: lightImg.height,
    numChannels: 4,
  );
  for (int y = 0; y < lightImg.height; y++) {
    for (int x = 0; x < lightImg.width; x++) {
      final p = lightImg.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;
      final minVal = (r < g ? (r < b ? r : b) : (g < b ? g : b)).toDouble();
      if (minVal >= 252) {
        lightTransparent.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (minVal > 230) {
        final alphaFactor = (252.0 - minVal) / 22.0;
        final a = (alphaFactor * 255).clamp(0, 255).round();
        lightTransparent.setPixelRgba(x, y, r, g, b, a);
      } else {
        lightTransparent.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  // 2. Transparent Dark Logo for in-app widgets
  final darkTransparent = img.Image(
    width: darkImg.width,
    height: darkImg.height,
    numChannels: 4,
  );
  for (int y = 0; y < darkImg.height; y++) {
    for (int x = 0; x < darkImg.width; x++) {
      final p = darkImg.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;
      final maxVal = (r > g ? (r > b ? r : b) : (g > b ? g : b)).toDouble();
      if (maxVal <= 6) {
        darkTransparent.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (maxVal < 30) {
        final alphaFactor = (maxVal - 6.0) / 24.0;
        final a = (alphaFactor * 255).clamp(0, 255).round();
        darkTransparent.setPixelRgba(x, y, r, g, b, a);
      } else {
        darkTransparent.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  File('assets/images/logo_light.png').writeAsBytesSync(img.encodePng(lightTransparent));
  File('assets/images/logo_dark.png').writeAsBytesSync(img.encodePng(darkTransparent));
  File('assets/images/logo_light_solid.png').writeAsBytesSync(img.encodePng(lightImg));
  File('assets/images/logo_dark_solid.png').writeAsBytesSync(img.encodePng(darkImg));
  print('Saved in-app logo assets.');

  // 3. iOS AppIcon set (both Light & iOS 18 Dark appearance)
  final iosIconDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

  // Standard sizes
  final Map<String, int> iosSizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
  };

  for (final entry in iosSizes.entries) {
    final size = entry.value;
    final resized = img.copyResize(lightImg, width: size, height: size, interpolation: img.Interpolation.linear);
    File('$iosIconDir/${entry.key}').writeAsBytesSync(img.encodePng(resized));
  }

  // 1024x1024 Marketing Light
  File('$iosIconDir/Icon-App-1024x1024@1x.png').writeAsBytesSync(img.encodePng(lightImg));
  // 1024x1024 Marketing Dark (iOS 18)
  File('$iosIconDir/Icon-App-1024x1024-Dark.png').writeAsBytesSync(img.encodePng(darkImg));

  // Update Contents.json with dark appearance
  final contentsJson = {
    "images": [
      {"size": "20x20", "idiom": "iphone", "filename": "Icon-App-20x20@2x.png", "scale": "2x"},
      {"size": "20x20", "idiom": "iphone", "filename": "Icon-App-20x20@3x.png", "scale": "3x"},
      {"size": "29x29", "idiom": "iphone", "filename": "Icon-App-29x29@1x.png", "scale": "1x"},
      {"size": "29x29", "idiom": "iphone", "filename": "Icon-App-29x29@2x.png", "scale": "2x"},
      {"size": "29x29", "idiom": "iphone", "filename": "Icon-App-29x29@3x.png", "scale": "3x"},
      {"size": "40x40", "idiom": "iphone", "filename": "Icon-App-40x40@2x.png", "scale": "2x"},
      {"size": "40x40", "idiom": "iphone", "filename": "Icon-App-40x40@3x.png", "scale": "3x"},
      {"size": "60x60", "idiom": "iphone", "filename": "Icon-App-60x60@2x.png", "scale": "2x"},
      {"size": "60x60", "idiom": "iphone", "filename": "Icon-App-60x60@3x.png", "scale": "3x"},
      {"size": "20x20", "idiom": "ipad", "filename": "Icon-App-20x20@1x.png", "scale": "1x"},
      {"size": "20x20", "idiom": "ipad", "filename": "Icon-App-20x20@2x.png", "scale": "2x"},
      {"size": "29x29", "idiom": "ipad", "filename": "Icon-App-29x29@1x.png", "scale": "1x"},
      {"size": "29x29", "idiom": "ipad", "filename": "Icon-App-29x29@2x.png", "scale": "2x"},
      {"size": "40x40", "idiom": "ipad", "filename": "Icon-App-40x40@1x.png", "scale": "1x"},
      {"size": "40x40", "idiom": "ipad", "filename": "Icon-App-40x40@2x.png", "scale": "2x"},
      {"size": "76x76", "idiom": "ipad", "filename": "Icon-App-76x76@1x.png", "scale": "1x"},
      {"size": "76x76", "idiom": "ipad", "filename": "Icon-App-76x76@2x.png", "scale": "2x"},
      {"size": "83.5x83.5", "idiom": "ipad", "filename": "Icon-App-83.5x83.5@2x.png", "scale": "2x"},
      {"size": "1024x1024", "idiom": "ios-marketing", "filename": "Icon-App-1024x1024@1x.png", "scale": "1x"},
      {
        "appearances": [
          {"appearance": "luminosity", "value": "dark"}
        ],
        "size": "1024x1024",
        "idiom": "ios-marketing",
        "filename": "Icon-App-1024x1024-Dark.png",
        "scale": "1x"
      }
    ],
    "info": {"version": 1, "author": "xcode"}
  };
  File('$iosIconDir/Contents.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(contentsJson));
  print('Updated iOS AppIcon with Light + iOS 18 Dark Mode support.');

  // 4. Android launcher icons
  final Map<String, int> androidSizes = {
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in androidSizes.entries) {
    final size = entry.value;
    final resized = img.copyResize(darkImg, width: size, height: size, interpolation: img.Interpolation.linear);
    File(entry.key).parent.createSync(recursive: true);
    File(entry.key).writeAsBytesSync(img.encodePng(resized));
  }
  print('Saved all Android launcher icons.');

  // 5. Web icons & favicon
  final web192 = img.copyResize(darkImg, width: 192, height: 192, interpolation: img.Interpolation.linear);
  final web512 = img.copyResize(darkImg, width: 512, height: 512, interpolation: img.Interpolation.linear);
  final favicon = img.copyResize(darkImg, width: 64, height: 64, interpolation: img.Interpolation.linear);

  File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(web192));
  File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(web512));
  File('web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(web192));
  File('web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(web512));
  File('web/favicon.png').writeAsBytesSync(img.encodePng(favicon));
  print('Saved all Web icons and favicon.');

  print('=== Done ===');
}
