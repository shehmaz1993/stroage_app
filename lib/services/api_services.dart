
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

  Stream<double> uploadFile({
    required String filePath,
    required String fileName,
    required int startByte,
    CancelToken? cancelToken,
  }) {
    // 1. Initialize the StreamController synchronously.
    final controller = StreamController<double>();

    // 2. Immediately Invoke an Anonymous Asynchronous Function (IIAF).
    // This starts the complex logic on the event loop, allowing the function
    // to return the stream instantly (Step 3).
    (() async {
      // --- All Asynchronous Logic is inside this block ---

      try {
        if (_accessToken == null) {
          await getToken();
        }

        const String jsonPatchPayload = '[{"op":"replace","path":"/updateBy","value":123}]';

        final file = File(filePath);
        if (!await file.exists()) {
          // Throwing here will be caught by the outer catch block
          throw Exception('File not found at path: $filePath');
        }
        final options = Options(
          headers: {
            // NOTE: Header name depends on your backend (e.g., 'Content-Range', 'X-Upload-Offset')
            'X-Upload-Offset': startByte.toString(),
          },
        );

        final formData = FormData.fromMap({
          // Ensure file existence before calling MultipartFile.fromFile
          'file': await MultipartFile.fromFile(filePath, filename: fileName),
          'jsonPatch': jsonPatchPayload,
        });
        final int absoluteTotalBytes = await file.length();
        // Execute the Dio request
        await _dio.patch(
          updateAppUrl,
          data: formData,
          options: options,
          onSendProgress: (count, total) {
            if (total != -1) {
              double totalBytesSent = (count + startByte).toDouble();
              double progress = totalBytesSent / absoluteTotalBytes;
              print('progress is $progress');
              // Safely add progress to the stream
              if (!controller.isClosed) {
                controller.add(progress);
              }
            }
          },
        );

        // On successful completion
        controller.add(1.0);
        print('APIProvider: File upload PATCH complete.');

      } on DioException catch (e) {
        // Catch network-specific errors and propagate them through the stream
        if (!controller.isClosed) {
          controller.addError(e);
        }
        rethrow;
      } catch (e) {
        // Catch file-specific errors (like "File not found")
        if (!controller.isClosed) {
          controller.addError(e);
        }
        rethrow;
      } finally {
        // Ensure the stream is closed, regardless of success or failure.
        if (!controller.isClosed) {
          await controller.close();
        }
      }

      // --- End of Asynchronous Logic ---
    })(); // <-- The final '()' immediately executes the async function.

    // 3. Return the stream synchronously before the upload even begins.
    return controller.stream;
  }

 /* Stream<double> uploadFile({
    required String filePath,
    required String fileName,
  }) { // <-- NO async* here!

    // The rest of the logic remains the same, using a controller to feed the stream
    // but the function returns the stream immediately.

    // 1. Initialize the StreamController
    final controller = StreamController<double>();

    // 2. Wrap the asynchronous work in a future (or just execute it)
    // This allows the function to return the stream instantly while the upload runs asynchronously.
    Future<void> runUpload() async {
      // 3. Keep the token logic, but it needs to be inside the async block
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

      try {
        await _dio.patch(
          updateAppUrl,
          data: formData,
          onSendProgress: (count, total) {
            if (total != -1) {
              double progress = count / total;
              print('progress is $progress');
              if (!controller.isClosed) {
                controller.add(progress); // Emit real-time progress
              }
            }
          },
        );

        // 4. On successful completion
        controller.add(1.0);
        print('APIProvider: File upload PATCH complete.');
      } on DioException catch (e) {
        // 5. On error
        if (!controller.isClosed) {
          controller.addError(e);
        }
        // Re-throw the error to be caught by the service layer's listener
        rethrow;
      } finally {
        // 6. Close the stream, ensuring the onDone callback fires on the listener
        await controller.close();
      }
    }

    // 7. Execute the upload logic immediately
    runUpload();

    // 8. CRITICAL: Return the stream immediately before the upload is finished.
    return controller.stream;
  }*/
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