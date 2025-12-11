
import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../utils/api_endpoints.dart';

class ApiProvider{

  final Dio _dio;
  final String authUrl = ApiEndpoints.AUTH_TOKEN;
  final String updateAppUrl = ApiEndpoints.UPDATE_APP;
  final String basicAuthHeader = ApiEndpoints.AUTH_BASIC_HEADER;
  final String listAppsUrl = ApiEndpoints.GET_PERMITTED_APPS;

  String? _accessToken;

  Future<void>? _tokenRefreshFuture;

  ApiProvider(this._dio) {

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_accessToken == null && options.path != authUrl) {
          await getToken();
        }
        if (_accessToken != null && options.path != authUrl) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);

      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401 && _accessToken != null) {
          _accessToken = null; // Invalidate token

          // Re-attempt authentication and retry the request
          try {
            await getToken();
            // If successful, create a new request and proceed
            return handler.resolve(await _dio.request(
              e.requestOptions.path,
              options: Options(
                method: e.requestOptions.method,
                headers: e.requestOptions.headers,
              ),
              data: e.requestOptions.data,
              queryParameters: e.requestOptions.queryParameters,
            ));
          } catch (_) {
            // If token refresh fails, continue to reject the request
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<void> getToken() async {
    if (_accessToken != null) return;
    if (_tokenRefreshFuture != null) {
      return _tokenRefreshFuture;
    }

    _tokenRefreshFuture = _performTokenRefresh();
    await _tokenRefreshFuture;
    _tokenRefreshFuture = null; // Clear the future after completion
  }


  Future<void> _performTokenRefresh() async {
    try {
      final response = await _dio.post(
        authUrl,
        options: Options(
          headers: {
            'Authorization': basicAuthHeader,
            'Content-Type': 'application/x-www-form-urlencoded'
          },
        ),
        data: 'grant_type=password&scope=profile&username=abir&password=ati123',
      );

      if (response.statusCode == 200 && response.data['access_token'] != null) {
        _accessToken = response.data['access_token'];
        print('APIProvider: Token fetched successfully.');
      } else {
        throw DioException(requestOptions: response.requestOptions, error: 'Failed to get access token');
      }
    } catch (e) {
      print('Authentication Error: $e');
      _accessToken = null;
      rethrow;
    }
  }


// Assuming ApiProvider class structure
// ...

  Future<String> uploadFile({
    required String filePath,
    required String fileName,
    required int startByte,
    required Function(int count, int total)? onSendProgress, // 🎯 NEW: Dio's progress callback
    CancelToken? cancelToken,
  }) async { // 🎯 Function is now declared 'async'

    if (_accessToken == null) {
      await getToken();
    }

    const String jsonPatchPayload = '[{"op":"replace","path":"/updateBy","value":123}]';

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found at path: $filePath');
    }
    // Note: absoluteTotalBytes is not strictly needed here since we use startByte in the Service layer,
    // but useful for local checks.
    // final int absoluteTotalBytes = await file.length();

    final options = Options(
      headers: {
        'X-Upload-Offset': startByte.toString(),
      },
    );

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'jsonPatch': jsonPatchPayload,
    });

    try {
      // 2. Execute the Dio request and await the final Response
      final Response response = await _dio.patch(
        updateAppUrl,
        data: formData,
        options: options,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );

      // 3. Handle the server response and retrieve the URL
      if (response.statusCode == 200 || response.statusCode == 201) {

        // Use print() to see the response data as requested:
        print('APIProvider: Dio Response Data Received: ${response.data}');

        // --- MOCK LOGIC START ---
        // In a real app, you would parse: return response.data['download_url'] as String;

        final mockDownloadUrl = response.data.toString();

        return mockDownloadUrl; // 🎯 Return the Download URL, fulfilling the Future<String>

      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }


  Future<Response> downloadFile({
    required String fileUrl,
    required String savePath,
    required String fileId,
    int startByte = 0,
    required CancelToken cancelToken,
    Function(int count, int total)? onReceiveProgress, // Download Progress
  }) async {
    if (_accessToken == null) {
      await getToken();
    }
    final options = Options(
      responseType: ResponseType.stream,
    );
    if (startByte > 0) {

      options.headers?['Range'] = 'bytes=$startByte-';

    }

    return _dio.download(
      fileUrl,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: options,
      cancelToken: cancelToken,
      deleteOnError: false, // Keep partially downloaded file for resumption
    );
  }


  Future<Response> getAppList() async {
    if (_accessToken == null) {
      await getToken();
    }
    return _dio.get(listAppsUrl);
  }


}