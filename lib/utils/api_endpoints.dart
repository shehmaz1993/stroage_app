class ApiEndpoints {
  // Base URLs (if the port/IP were consistent, they would be here)
  static const String BASE_URL_AUTH = 'http://54.241.200.172:8801';
  static const String BASE_URL_SETUP = 'http://54.241.200.172:8800';

  // --- Auth Endpoints ---
  static const String AUTH_TOKEN = '$BASE_URL_AUTH/auth-ws/oauth2/token';
  static const String AUTH_BASIC_HEADER = 'Basic Y2xpZW50OnNlY3JldA=='; // Should ideally be loaded from environment/native config

  // --- Transfer/Setup Endpoints ---
  static const String UPDATE_APP = '$BASE_URL_SETUP/setup-ws/api/v1/app/update-app/2';
  static const String GET_PERMITTED_APPS = '$BASE_URL_SETUP/setup-ws/api/v1/app/get-permitted-apps?companyId=2';
}