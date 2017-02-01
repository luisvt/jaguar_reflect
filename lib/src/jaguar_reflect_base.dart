// Copyright (c) 2017, Ravi Teja Gudapati. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library jaguar_reflect.base;

import 'dart:async';
import 'package:jaguar/jaguar.dart' as j;
import 'dart:mirrors';

part 'internal.dart';
part 'route.dart';

class JaguarReflected implements j.RequestHandler {
  final j.RequestHandler _handler;

  final List<ReflectedRoute> _routes = <ReflectedRoute>[];

  JaguarReflected(this._handler) {
    _parse();
  }

  void _parse() {
    _routes.clear();

    InstanceMirror im = reflect(_handler);
    ClassMirror mirror = im.type;
    mirror.declarations.forEach((Symbol s, DeclarationMirror decl) {
      if (decl.isPrivate) return;
      if (decl is! MethodMirror) return;

      final List<j.RouteWrapper> wrappers = [];

      final List<j.RouteBase> routes = decl.metadata
          .where((InstanceMirror annot) => annot.reflectee is j.RouteBase)
          .map((InstanceMirror annot) => annot.reflectee)
          .toList();
      if (routes.length == 0) return;

      InstanceMirror method = im.getField(s);
      print(method);

      print(routes);
      routes.forEach((j.RouteBase route) {
        new ReflectedRoute.build(method.reflectee, route, wrappers);
      });
    });

    return null;
  }

  Future<j.Response> handleRequest(j.Request req, {String prefix}) async {
    for (ReflectedRoute route in _routes) {
      j.Response response = await route.handleRequest(req, prefix: prefix);
      if (response is j.Response) {
        return response;
      }
    }

    return null;
  }
}
