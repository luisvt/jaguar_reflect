// Copyright (c) 2017, Ravi Teja Gudapati. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library jaguar_reflect.base;

import 'dart:async';
import 'package:jaguar/jaguar.dart' as j;
import 'dart:mirrors';
import 'package:quiver/core.dart';

part 'route.dart';

part 'inputs/inject.dart';
part 'inputs/input.dart';
part 'interceptor/interceptor.dart';
part 'interceptor/wrapper_maker.dart';

class JaguarReflected implements j.RequestHandler {
  final dynamic _handler;

  final List<ReflectedRoute> _routes = <ReflectedRoute>[];

  JaguarReflected(this._handler) {
    _parseApi();
  }

  void _parseApi() {
    _routes.clear();

    InstanceMirror im = reflect(_handler);
    final List<j.Api> apis = im.type.metadata
        .map((InstanceMirror aim) => aim.reflectee)
        .where((dynamic ref) => ref is j.Api)
        .toList() as List<j.Api>;
    if (apis.length == 0) {
      throw new Exception('Handler is not decorated with Api!');
    }

    final List<j.RouteWrapper> wrappers = im.type.metadata
        .where((InstanceMirror annot) => annot.reflectee is j.RouteWrapper)
        .map((InstanceMirror annot) => annot.reflectee)
        .toList() as List<j.RouteWrapper>;

    _parse(im, apis.first.url, topWrapper: wrappers);
  }

  void _parse(InstanceMirror im, String pathPrefix,
      {List<j.RouteWrapper> topWrapper: const []}) {
    im.type.declarations.forEach((Symbol s, DeclarationMirror decl) {
      if (decl.isPrivate) return;

      if (decl is VariableMirror) {
        final List<j.Group> groups = decl.metadata
            .where((InstanceMirror annot) => annot.reflectee is j.Group)
            .map((InstanceMirror annot) => annot.reflectee)
            .toList() as List<j.Group>;

        if (groups.length == 0) return;

        if (!decl.isFinal) {
          throw new Exception('Group must be final!');
        }

        InstanceMirror gim = im.getField(s);
        dynamic group = gim.reflectee;
        if (group == null) {
          throw new Exception('Group cannot be null!');
        }

        List<j.RouteGroup> rg = gim.type.metadata
            .where((InstanceMirror annot) => annot.reflectee is j.RouteGroup)
            .map((InstanceMirror annot) => annot.reflectee)
            .toList() as List<j.RouteGroup>;

        if (rg.length == 0) {
          throw new Exception('Group must be annotated with RouteGroup!');
        }

        final List<j.RouteWrapper> wrappers = gim.type.metadata
            .where((InstanceMirror annot) => annot.reflectee is j.RouteWrapper)
            .map((InstanceMirror annot) => annot.reflectee)
            .toList() as List<j.RouteWrapper>;

        _parse(gim, pathPrefix + groups.first.path + rg.first.path,
            topWrapper: wrappers);
      }

      if (decl is! MethodMirror) return;

      final List<j.RouteBase> routes = decl.metadata
          .where((InstanceMirror annot) => annot.reflectee is j.RouteBase)
          .map((InstanceMirror annot) => annot.reflectee)
          .toList() as List<j.RouteBase>;
      if (routes.length == 0) return;

      final List<j.RouteWrapper> wrappers = decl.metadata
          .where((InstanceMirror annot) => annot.reflectee is j.RouteWrapper)
          .map((InstanceMirror annot) => annot.reflectee)
          .toList() as List<j.RouteWrapper>;

      wrappers.insertAll(0, topWrapper);

      InstanceMirror method = im.getField(s);

      routes
          .map((j.RouteBase route) => new ReflectedRoute.build(
              method.reflectee, route, pathPrefix, wrappers, im))
          .forEach(_routes.add);
    });
  }

  Future<j.Response> handleRequest(j.Request req, {String prefix: ''}) async {
    for (ReflectedRoute route in _routes) {
      j.Response response =
          await route.handleRequest(req, prefix: prefix + route.prefix);
      if (response is j.Response) {
        return response;
      }
    }

    return null;
  }
}

JaguarReflected reflectJaguar(Object routeGroup) =>
    new JaguarReflected(routeGroup);
