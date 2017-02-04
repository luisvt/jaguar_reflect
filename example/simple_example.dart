// Copyright (c) 2017, Ravi Teja Gudapati. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:jaguar_reflect/jaguar_reflect.dart';
import 'package:jaguar/jaguar.dart';

@RouteGroup()
class ExampleGroup1 {
  @Get(path: '/api/hi')
  String sayHi() => 'hi';
}

@Api()
class ExampleApi implements RequestHandler {
  JaguarReflected _reflected;

  ExampleApi() {
    _reflected = new JaguarReflected(this);
  }

  @Get(path: '/api/hello')
  String sayHello() => 'hello';

  @Group()
  final ExampleGroup1 group1 = new ExampleGroup1();

  Future<Response> handleRequest(Request req, {String prefix}) =>
      _reflected.handleRequest(req, prefix: prefix);
}

main() async {
  final api = new ExampleApi();
}
