import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:markdown/markdown.dart' as md;
import 'package:html2md/html2md.dart' as h2m;

/// Utilities for handling and sanitizing HTML content from Mumble.
class HtmlUtils {
  /// Some Mumble clients URL-encode or add newlines to the base64 data in data URIs.
  /// This method finds those data URIs and ensures they are properly decoded and cleaned.
  /// It also linkifies plain text URLs if they aren't already part of an <a> tag.
  static String sanitizeMumbleHtml(String html) {
    if (html.isEmpty) return html;

    // 1. Linkify plain text URLs (only if they aren't already part of an <a> tag)
    String linkifiedHtml = linkify(html);

    // 2. Pattern to find data URIs in src attributes
    // We use a broader match and then clean the inside.
    final dataUriPattern = RegExp(
      r"""data:[^;]+;base64,[^"'>]+""",
      caseSensitive: false,
    );

    return linkifiedHtml.replaceAllMapped(dataUriPattern, (match) {
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

  /// Converts plain URLs in text to clickable HTML <a> tags.
  static String linkify(String html) {
    if (html.isEmpty) return html;

    // Regex for URLs that are NOT preceded by href=" or src="
    // We also want to avoid linkifying if it's already inside an <a> tag.
    // Since Dart's RegExp is limited, we'll use a simple heuristic:
    // If it already has <a> tags, we assume it's already linkified.
    if (html.contains('<a') || html.contains('<img')) {
      return html;
    }

    final urlRegex = RegExp(
      r'(https?://[^\s<"]+)',
      caseSensitive: false,
    );

    return html.replaceAllMapped(urlRegex, (match) {
      final url = match.group(1)!; // Use the first group (the URL itself)
      
      // Heuristic to handle trailing punctuation (e.g., at the end of a sentence)
      var cleanedUrl = url;
      var suffix = '';
      
      // While the URL ends with a common trailing punctuation char that shouldn't be part of the URL
      // We check if it's likely not part of a query string or similar
      final trailingPunctuation = RegExp(r'[.,;!?)\]]$');
      while (trailingPunctuation.hasMatch(cleanedUrl)) {
        // If it ends with ')', check if there's a matching '(' in the URL (e.g. Wikipedia links)
        if (cleanedUrl.endsWith(')') && cleanedUrl.contains('(')) {
          break;
        }
        suffix = cleanedUrl.substring(cleanedUrl.length - 1) + suffix;
        cleanedUrl = cleanedUrl.substring(0, cleanedUrl.length - 1);
      }
      
      // Image preview check
      final lowerUrl = cleanedUrl.toLowerCase();
      if (lowerUrl.endsWith('.gif') || 
          lowerUrl.endsWith('.png') || 
          lowerUrl.endsWith('.jpg') || 
          lowerUrl.endsWith('.jpeg') || 
          lowerUrl.endsWith('.webp')) {
        return '<a href="$cleanedUrl"><img src="$cleanedUrl" /></a>$suffix';
      }

      return '<a href="$cleanedUrl">$cleanedUrl</a>$suffix';
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

  /// Converts Markdown to Mumble-compatible HTML.
  static String markdownToHtml(String markdown) {
    if (markdown.isEmpty) return markdown;
    
    // Normalize newlines to ensure consistent parsing
    final normalized = markdown.replaceAll('\r\n', '\n');
    
    // Use GitHub Flavored Markdown for better compatibility with modern expectations
    return md.markdownToHtml(
      normalized,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
  }

  /// Converts HTML to Markdown for easy copying/pasting between apps.
  static String htmlToMarkdown(String html) {
    if (html.isEmpty) return html;
    
    try {
      // 1. We don't want to convert images to markdown because they are usually base64
      // and would bloat the clipboard. We'll replace <img> tags with [Image]
      String cleanHtml = html.replaceAll(RegExp(r'<img[^>]*>'), '[Image]');
      
      // 2. Convert to markdown
      return h2m.convert(cleanHtml);
    } catch (e) {
      // Fallback: strip tags if conversion fails
      return html.replaceAll(RegExp(r'<[^>]*>'), '');
    }
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
