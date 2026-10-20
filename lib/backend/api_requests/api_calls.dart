import '/flutter_flow/flutter_flow_util.dart';
import '/backend/backend_session.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

String _currentAppLanguage() {
  final locale = FFLocalizations.getStoredLocale()?.languageCode.toLowerCase();
  return locale != null && locale.startsWith('kk') ? 'kk' : 'ru';
}

class SmsCall {
  static Future<ApiCallResponse> call({
    String? phones = '',
    String? mes = '',
  }) async {
    return const ApiCallResponse(
      {
        'success': false,
        'error': 'SMS отправляется только через backend.',
      },
      {},
      503,
    );
  }
}

class TokenCall {
  static Future<ApiCallResponse> call({
    String? uid = '',
  }) async {
    return const ApiCallResponse(
      {
        'success': false,
        'error': 'Токен авторизации выдает только backend.',
      },
      {},
      503,
    );
  }

  static String? token(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.token''',
      ));
}

class GetStritCall {
  static Future<ApiCallResponse> call({
    String? q = '',
    String? location = '',
    String? language = '',
  }) async {
    final resolvedLanguage = (language ?? '').trim().isNotEmpty
        ? language!.trim()
        : _currentAppLanguage();
    final response = await mtaxiBackendCall('placesAutocomplete', {
      'input': q,
      'locationbias': location,
      'language': resolvedLanguage,
      'types': "address",
    });
    return ApiCallResponse(
        response, {}, response['success'] == true ? 200 : 502);
  }

  static List<String>? adres(dynamic response) => (getJsonField(
        response,
        r'''$.predictions[:].description''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
}

class GetCityCall {
  static Future<ApiCallResponse> call({
    String? input = '',
  }) async {
    final response = await mtaxiBackendCall('placesAutocomplete', {
      'input': input,
      'types': "(regions)",
      'language': _currentAppLanguage(),
    });
    return ApiCallResponse(
        response, {}, response['success'] == true ? 200 : 502);
  }

  static List<String>? adres(dynamic response) => (getJsonField(
        response,
        r'''$.results[:].formatted_address''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
  static String? city(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.plus_code.compound_code''',
      ));
}

class CoordsCall {
  static Future<ApiCallResponse> call({
    double? longitude,
    double? latitude,
  }) async {
    final response = await mtaxiBackendCall('reverseGeocodeLookup', {
      'lng': longitude,
      'lat': latitude,
    });
    return ApiCallResponse(
        response, {}, response['success'] == true ? 200 : 502);
  }
}

class CityCall {
  static Future<ApiCallResponse> call({
    String? q = '',
  }) async {
    final response = await mtaxiBackendCall('placesAutocomplete', {
      'input': q,
      'types': '(regions)',
      'language': _currentAppLanguage(),
    });
    return ApiCallResponse(
        response, {}, response['success'] == true ? 200 : 502);
  }
}

class AdresCall {
  static Future<ApiCallResponse> call({
    String? q = '',
    String? city = '',
  }) async {
    final response = await mtaxiBackendCall('placesAutocomplete', {
      'input':
          [city, q].where((item) => (item ?? '').trim().isNotEmpty).join(', '),
      'types': 'address',
      'language': _currentAppLanguage(),
    });
    return ApiCallResponse(
        response, {}, response['success'] == true ? 200 : 502);
  }
}

class CreatePaymentCall {
  static Future<ApiCallResponse> call({
    String? uid = '',
    double? amount,
  }) async {
    final response = await mtaxiBackendCall('createDriverTopUpPayment', {
      'amount': amount,
    });
    final compatible = Map<String, dynamic>.from(response);
    compatible['order_id'] ??= response['paymentId'];
    compatible['payment_url'] ??= response['paymentUrl'];
    return ApiCallResponse(
        compatible, {}, response['success'] == true ? 200 : 502);
  }

  static String? orderId(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.order_id''',
      ));
  static String? url(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.payment_url''',
      ));
}

class VivodCall {
  static Future<ApiCallResponse> call({
    String? uid = '',
    double? amount,
    String? cart = '',
  }) async {
    final response = await mtaxiBackendCall('createDriverWithdrawal', {
      'amount': amount,
      'cardNumber': cart,
    });
    final compatible = Map<String, dynamic>.from(response);
    compatible['withdraw_id'] ??= response['withdrawalId'];
    compatible['message'] ??= response['error'];
    return ApiCallResponse(
        compatible, {}, response['success'] == true ? 200 : 502);
  }

  static String? message(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.message''',
      ));
  static String? id(dynamic response) => castToType<String>(getJsonField(
        response,
        r'''$.withdraw_id''',
      ));
  static bool? success(dynamic response) => castToType<bool>(getJsonField(
        response,
        r'''$.success''',
      ));
}

class SearchStreetCall {
  static Future<ApiCallResponse> call({
    String? q = '',
    String? sessionToken = '',
    String? proximity = '',
    String? origin = '',
  }) async {
    final response = await mtaxiBackendCall('placesAutocomplete', {
      'input': q,
      'language': _currentAppLanguage(),
      'types': "address",
    });
    return ApiCallResponse(
        response, {}, response['success'] == true ? 200 : 502);
  }

  static List<String>? name(dynamic response) => (getJsonField(
        response,
        r'''$.predictions[:].description''',
        true,
      ) as List?)
          ?.withoutNulls
          .map((x) => castToType<String>(x))
          .withoutNulls
          .toList();
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String? escapeStringForJson(String? input) {
  if (input == null) {
    return null;
  }
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}
