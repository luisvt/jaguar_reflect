library jaguar_reflect.interceptor.make_param_from_method.client;

import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;

const String kHostname = 'localhost';

const int kPort = 8080;

final http.Client _client = new http.Client();

Future<Null> printHttpClientResponse(http.Response resp) async {
  print('=========================');
  print("body:");
  print(resp.body);
  print("statusCode:");
  print(resp.statusCode);
  print("headers:");
  print(resp.headers);
  print('=========================');
}

Future<Null> execHello() async {
  String url = "http://$kHostname:$kPort/api/hello";
  http.Response resp = await _client.get(url);

  await printHttpClientResponse(resp);
}

main() async {
  await execHello();
  exit(0);
}