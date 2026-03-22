import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Utilities for handling and sanitizing HTML content from Mumble.
class HtmlUtils {
  /// Some Mumble clients URL-encode or add newlines to the base64 data in data URIs.
  /// This method finds those data URIs and ensures they are properly decoded and cleaned.
  static String sanitizeMumbleHtml(String html) {
    if (html.isEmpty) return html;

    // Pattern to find data URIs in src attributes
    // We use a broader match and then clean the inside.
    final dataUriPattern = RegExp(
      r"""data:[^;]+;base64,[^"'>]+""",
      caseSensitive: false,
    );

    return html.replaceAllMapped(dataUriPattern, (match) {
      String dataUri = match.group(0)!;
      
      // 1. Handle URL-encoding if present
      if (dataUri.contains('%')) {
        try {
          const base64Marker = 'base64,';
          final markerIndex = dataUri.indexOf(base64Marker);
          if (markerIndex != -1) {
            final prefix = dataUri.substring(0, markerIndex + base64Marker.length);
            final base64Part = dataUri.substring(markerIndex + base64Marker.length);
            
            // Re-decode just the base64 part
            final decodedBase64 = Uri.decodeComponent(base64Part);
            dataUri = '$prefix$decodedBase64';
          }
        } catch (_) {}
      }
      
      // 2. Remove any line breaks or whitespace from the base64 data portion
      // Some clients insert \n or \r\n which can break standard decoders.
      const base64Marker = 'base64,';
      final markerIndex = dataUri.indexOf(base64Marker);
      if (markerIndex != -1) {
        final prefix = dataUri.substring(0, markerIndex + base64Marker.length);
        final base64Part = dataUri.substring(markerIndex + base64Marker.length);
        final cleanedBase64 = base64Part.replaceAll(RegExp(r'\s+'), '');
        dataUri = '$prefix$cleanedBase64';
      }

      return dataUri;
    });
  }

  /// Formats image bytes as a Mumble-compatible HTML <img> tag.
  /// Converts the image to a compressed JPEG to avoid Mumble's text message size limits.
  static String imageToHtml(Uint8List bytes) {
    String base64String;
    String mimeType;

    try {
      // Decode the raw pasted bytes (PNG or other format from Pasteboard)
      final image = img.decodeImage(bytes);
      if (image != null) {
        // Resize if it's too large to save space (e.g., max 1024 width/height)
        img.Image processedImage = image;
        if (image.width > 1024 || image.height > 1024) {
          processedImage = img.copyResize(
            image,
            width: image.width >= image.height ? 1024 : null,
            height: image.height > image.width ? 1024 : null,
          );
        }

        // Encode as JPEG to compress it well under the ~128KB limit
        final jpegBytes = img.encodeJpg(processedImage, quality: 75);
        base64String = base64Encode(jpegBytes);
        mimeType = 'image/jpeg';
      } else {
        // Fallback if we cannot decode it
        base64String = base64Encode(bytes);
        mimeType = 'image/png';
      }
    } catch (e) {
      // Fallback on exception
      base64String = base64Encode(bytes);
      mimeType = 'image/png';
    }

    // Wrap in standard HTML that old Qt clients usually accept
    return '<img src="data:$mimeType;base64,$base64String" />';
  }

  /// Extracts all image sources from an HTML string.
  static List<String> extractImageSources(String html) {
    if (html.isEmpty) return [];
    
    final dataUriPattern = RegExp(
      r"""data:[^;]+;base64,[^"'>]+""",
      caseSensitive: false,
    );
    
    // Also match HTTP/HTTPS image links if present
    final httpPattern = RegExp(
      r"""src=["'](https?://[^"']+)["']""",
      caseSensitive: false,
    );

    final sources = <String>{};
    for (final match in dataUriPattern.allMatches(html)) {
      sources.add(match.group(0)!);
    }
    for (final match in httpPattern.allMatches(html)) {
      sources.add(match.group(1)!);
    }
    
    return sources.toList();
  }
}
