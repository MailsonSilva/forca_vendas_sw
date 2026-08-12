import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

/// Start SuportwareServerlessApi Group Code

class SuportwareServerlessApiGroup {
  static String getBaseUrl() => 'https://api.suportware.com';
  static Map<String, String> headers = {
    'Content-Type': 'application/json',
  };
  static GetClientConfigCall getClientConfigCall = GetClientConfigCall();
}

class GetClientConfigCall {
  Future<ApiCallResponse> call({
    String? codigoEmpresa = '',
    String? codigoVendedor = '',
  }) async {
    final baseUrl = SuportwareServerlessApiGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: 'GetClientConfig',
      apiUrl:
          '$baseUrl/api/v1/get-client-config?codigoEmpresa=$codigoEmpresa&codigoVendedor=$codigoVendedor',
      callType: ApiCallType.GET,
      headers: {
        'Content-Type': 'application/json',
      },
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// End SuportwareServerlessApi Group Code

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
