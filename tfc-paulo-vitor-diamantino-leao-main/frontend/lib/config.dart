// Host das APIs. Para rodar local: flutter run -d chrome --dart-define=API_HOST=localhost
const String apiHost = String.fromEnvironment('API_HOST', defaultValue: '91.108.125.253');

const String backendUrl = 'http://$apiHost:3000';
const String vannaUrl = 'http://$apiHost:5000';
