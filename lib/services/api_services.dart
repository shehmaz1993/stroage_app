
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

  Stream<double> uploadFile({
    required String filePath,
    required String fileName,
  }) async* {
    if (_accessToken == null) {
      await getToken();
    }


    const String jsonPatchPayload = '[{"op":"replace","path":"/updateBy","value":123}]';

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File not found at path: $filePath');
    }


    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'jsonPatch': jsonPatchPayload,
    });

    final controller = StreamController<double>();

    try {

      await _dio.patch(
        updateAppUrl,
        data: formData,
        onSendProgress: (count, total) {
          if (total != -1) {
            double progress = count / total;
            controller.add(progress); // Emit real-time progress
          }
        },
      );

      controller.add(1.0);
      await controller.close();
      print('APIProvider: File upload PATCH complete.');
    } on DioException catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        await controller.close();
      }
      rethrow;
    }

  }
  Future<Response> downloadFile({
    required String fileUrl,
    required String savePath,
    required String fileId,
    int startByte = 0,
    Function(int count, int total)? onReceiveProgress, // Download Progress
  }) async {
    if (_accessToken == null) {
      await getToken();
    }
    final options = Options(
      responseType: ResponseType.stream,
    );
    if (startByte > 0) {
      // This tells the server to start sending data after the last successful byte.
      options.headers?['Range'] = 'bytes=$startByte-';
    }
    // Dio's download method handles the network request, the file creation,
    // and the writing of bytes to the specified savePath on the disk.
    return _dio.download(
      fileUrl,
      savePath, // This is the destination file path
      onReceiveProgress: onReceiveProgress, // Passes progress back to the caller (TransferService)
      options:options
    );
  }


  Future<Response> getAppList() async {
    if (_accessToken == null) {
      await getToken();
    }
    return _dio.get(listAppsUrl);
  }


}