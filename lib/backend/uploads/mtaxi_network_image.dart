import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '/auth/backend_auth/auth_util.dart';
import '/backend/backend_session.dart';

/// Backend uploads require an authenticated RPC on web and native platforms.
/// External images retain ordinary network loading; bearer tokens never go to them.
class MTaxiNetworkImage extends StatefulWidget {
  const MTaxiNetworkImage(this.url,
      {super.key,
      this.width,
      this.height,
      this.fit,
      this.errorBuilder,
      this.loadingBuilder,
      this.privateLoader});
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final Future<Uint8List> Function(String)? privateLoader;

  @override
  State<MTaxiNetworkImage> createState() => _MTaxiNetworkImageState();
}

class _MTaxiNetworkImageState extends State<MTaxiNetworkImage> {
  Future<Uint8List>? _image;
  String? _identity;
  String? _url;

  Future<Uint8List> _load() async {
    if (widget.privateLoader != null) return widget.privateLoader!(widget.url);
    final token = await getStoredBackendAccessToken();
    final response =
        await mtaxiBackendCall('downloadFile', {'url': widget.url});
    if (token.isEmpty || token != await getStoredBackendAccessToken()) {
      throw StateError('Session changed while loading media');
    }
    if (response['success'] != true) throw StateError('Media unavailable');
    return base64Decode(response['base64'] as String);
  }

  @override
  Widget build(BuildContext context) {
    if (Uri.tryParse(widget.url)?.path.startsWith('/uploads/') != true) {
      return Image.network(widget.url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorBuilder,
          loadingBuilder: widget.loadingBuilder);
    }
    if (_image == null || _url != widget.url || _identity != currentUserUid) {
      _identity = currentUserUid;
      _url = widget.url;
      _image = _load();
    }
    return FutureBuilder<Uint8List>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return widget.errorBuilder
                    ?.call(context, snapshot.error!, snapshot.stackTrace) ??
                const Icon(Icons.broken_image_outlined);
          }
          if (!snapshot.hasData) {
            return widget.loadingBuilder?.call(
                    context,
                    const SizedBox.shrink(),
                    const ImageChunkEvent(
                        cumulativeBytesLoaded: 0, expectedTotalBytes: 1)) ??
                SizedBox(
                    width: widget.width,
                    height: widget.height,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final image = Image.memory(snapshot.data!,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: widget.errorBuilder);
          return widget.loadingBuilder?.call(context, image, null) ?? image;
        });
  }
}
