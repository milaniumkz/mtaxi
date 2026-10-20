// ignore_for_file: unused_import, unnecessary_import

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import '/flutter_flow/lat_lng.dart';
import '/backend/backend_session.dart';
import '/backend/backend_calls/backend_calls.dart';

class GooglePlacesAutocomplete extends StatefulWidget {
  const GooglePlacesAutocomplete({
    Key? key,
    this.initialValue = '',
    this.hintText = '',
    this.country = 'both', // 'ru', 'kz', 'both'
    required this.onPlaceSelected,
    this.language = '',
  }) : super(key: key);

  final String initialValue;
  final String hintText;
  final String country;
  final ValueChanged<Map<String, dynamic>> onPlaceSelected;
  final String language;

  @override
  _GooglePlacesAutocompleteState createState() =>
      _GooglePlacesAutocompleteState();
}

class _GooglePlacesAutocompleteState extends State<GooglePlacesAutocomplete> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<dynamic> _predictions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  bool get _isKazakh =>
      FFLocalizations.of(context).languageCode.toLowerCase().startsWith('kk');

  String _tr(String ru, String kk) => _isKazakh ? kk : ru;

  String get _languageCode {
    final explicit = widget.language.trim().toLowerCase();
    if (explicit.startsWith('kk')) {
      return 'kk';
    }
    if (explicit.startsWith('ru')) {
      return 'ru';
    }
    return _isKazakh ? 'kk' : 'ru';
  }

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus && _controller.text.isNotEmpty) {
      _searchPlaces(_controller.text);
    } else {
      _hideOverlay();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _hideOverlay();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13191D) : Colors.white;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 4,
          color: surface,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(maxHeight: 200),
            child: _buildSuggestionsList(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildSuggestionsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1525);
    final mutedColor = isDark ? const Color(0xFF9EA8B0) : Colors.grey;
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_predictions.isEmpty) {
      return ListTile(
        title: Text(
          _tr('Ничего не найдено', 'Ештеңе табылмады'),
          style: TextStyle(color: mutedColor, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _predictions.length,
      itemBuilder: (context, index) {
        final prediction = _predictions[index];
        return ListTile(
          leading: const Icon(
            Icons.location_on,
            size: 20,
            color: Color(0xFF28D8C6),
          ),
          title: Text(
            prediction['description'] ?? '',
            style: TextStyle(fontSize: 14, color: textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _onPredictionSelected(prediction),
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 300), () {
      _searchPlaces(query);
    });
  }

  Future<void> _searchPlaces(String input) async {
    if (input.length < 2) {
      setState(() {
        _predictions = [];
      });
      _hideOverlay();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (!isMTaxiBackendEnabled) {
        setState(() {
          _predictions = [];
        });
        _hideOverlay();
        return;
      }
      final data = await makeCloudCall(
        'placesAutocomplete',
        {
          'input': input,
          'language': _languageCode,
          'country': widget.country,
          'types': 'address',
        },
        timeout: const Duration(seconds: 8),
      );

      if (data['status'] == 'OK' || data['success'] == true) {
        setState(() {
          _predictions = data['predictions'] ?? [];
        });

        if (_predictions.isNotEmpty) {
          _showOverlay();
        } else {
          _hideOverlay();
        }
      } else {
        print('Google Places API Error: ${data['status']}');
        setState(() {
          _predictions = [];
        });
        _hideOverlay();
      }
    } catch (e) {
      print('Ошибка поиска адресов: $e');
      setState(() {
        _predictions = [];
      });
      _hideOverlay();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onPredictionSelected(Map<String, dynamic> prediction) async {
    final String description = prediction['description'];
    final String placeId = prediction['place_id'];

    _controller.text = description;
    _hideOverlay();
    _focusNode.unfocus();

    // Получаем детали места с координатами
    await _getPlaceDetails(placeId, description);
  }

  Future<void> _getPlaceDetails(String placeId, String address) async {
    try {
      if (!isMTaxiBackendEnabled) {
        return;
      }
      final selected = _predictions.whereType<Map>().firstWhere(
            (item) => (item['place_id'] ?? '').toString() == placeId,
            orElse: () => const {},
          );
      final data = await makeCloudCall(
        'placeDetails',
        {
          'placeId': placeId,
          'address': address,
          'lat': selected['lat'],
          'lng': selected['lng'],
          'language': _languageCode,
        },
        timeout: const Duration(seconds: 8),
      );

      if (data['status'] == 'OK' || data['success'] == true) {
        final result = data['result'];

        // Извлекаем координаты
        final geometry = result['geometry'] ?? {};
        final location = geometry['location'] ?? {};
        LatLng? coordinates;

        if (location['lat'] != null && location['lng'] != null) {
          coordinates = LatLng(
            location['lat'].toDouble(),
            location['lng'].toDouble(),
          );
        }

        // Формируем результат с адресом и координатами
        final placeData = {
          'address': address,
          'formatted_address': result['formatted_address'] ?? address,
          'coordinates': coordinates,
          'place_id': placeId,
          'name': result['name'] ?? '',
          'address_components': result['address_components'] ?? [],
          'full_details': result, // Полные детали места
        };

        // Вызываем callback с данными
        widget.onPlaceSelected(placeData);

        print('Адрес: $address');
        print(
            'Координаты: ${coordinates?.latitude}, ${coordinates?.longitude}');
      }
    } catch (e) {
      print('Ошибка получения деталей места: $e');
    }
  }

  void _clearInput() {
    _controller.clear();
    _hideOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText.isNotEmpty
                ? widget.hintText
                : _tr('Введите адрес', 'Мекенжайды енгізіңіз'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 20),
                    onPressed: _clearInput,
                  )
                : (_isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.search, color: Colors.grey)),
            prefixIcon: Icon(Icons.location_on_outlined, color: Colors.blue),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          onChanged: _onSearchChanged,
          onTap: () {
            if (_controller.text.isNotEmpty && _predictions.isNotEmpty) {
              _showOverlay();
            }
          },
        ),
        SizedBox(height: 4),
        if (_isLoading)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _tr('Поиск адресов...', 'Мекенжайлар ізделуде...'),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
