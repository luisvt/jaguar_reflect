part of jaguar_reflect.base;

class ReflectedRoute implements j.RequestHandler {
  final j.RouteBase route;

  final Function handler;

  final ClosureMirror _invoker;

  final List<Inject> _required;

  final Set<RouteQueryParam> _optional;

  final List<ReflectedInterceptor> wrappers;

  ReflectedRoute(this.route, this.handler, this._invoker, this._required,
      this._optional, this.wrappers);

  Future<j.Response> handleRequest(j.Request request, {String prefix}) async {
    final j.PathParams pathParams = new j.PathParams();

    if (!route.match(request.uri.path, request.method, prefix, pathParams)) {
      return null;
    }

    final j.QueryParams queryParams =
    new j.QueryParams(request.uri.queryParameters);

    j.Response response = new j.Response(null,
        statusCode: route.statusCode, headers: route.headers);

    final List<_Inter> inters = [];
    final Map<InputInject, dynamic> results = {};
    try {
      for (ReflectedInterceptor wrapper in wrappers) {
        final j.Interceptor i = wrapper.routeWrapper.createInterceptor();
        final InstanceMirror im = reflect(i);
        final _Inter inter = new _Inter(wrapper, i, im);
        inters.add(inter);

        if (inter.wrapper._pre == null) continue;

        final List reqParam = [];

        for (Inject inj in inter.wrapper._pre.injects) {
          reqParam.add(_makeParam(inj, request, response, results, pathParams));
        }

        dynamic result = inter.interMirror.invoke(#pre, reqParam).reflectee;
        if (result is Future) {
          result = await result;
        }
        InputInject key = new InputInject(wrapper.interceptorType,
            id: wrapper.routeWrapper.id);
        results[key] = result;
      }

      {
        final List reqParam = [];
        for (Inject inj in _required) {
          reqParam.add(_makeParam(inj, request, response, results, pathParams));
        }

        final Map<Symbol, dynamic> optParams = {};
        for (RouteQueryParam p in _optional) {
          optParams[new Symbol(p.key)] = convertQueryParam(p, queryParams);
        }

        dynamic result = _invoker.apply(reqParam, optParams).reflectee;
        if (result is Future) {
          result = await result;
        }
        response.value = result;
      }

      // Interceptors post
      for (_Inter inter in inters.reversed) {
        if (inter.wrapper._post == null) continue;

        final List reqParam = [];

        for (Inject inj in inter.wrapper._post.injects) {
          reqParam.add(_makeParam(inj, request, response, results, pathParams));
        }

        dynamic resp = inter.interMirror.invoke(#post, reqParam).reflectee;
        if (resp is Future) {
          resp = await resp;
        }
        if (resp is j.Response) {
          response = resp;
        }
      }
    } catch (e) {
      for (_Inter inter in inters.reversed) {
        await inter.inter.onException();
      }
      rethrow;
    }

    return response;
  }

  dynamic _makeParam(Inject inj, j.Request request, j.Response response,
      Map<InputInject, dynamic> interceptorResults, j.PathParams pathParams) {
    if (inj is InputInject) {
      if (!interceptorResults.containsKey(inj)) {
        throw new Exception('Interceptor not found for Input!');
      }
      dynamic result = interceptorResults[inj];
      return result;
    } else if (inj is RouteResponseInject) {
      return response;
    } else if (inj is RequestInject) {
      return request;
    } else if (inj is HeaderInject) {
      return request.headers.value(inj.key);
    } else if (inj is HeadersInject) {
      return request.headers;
    } else if (inj is CookieInject) {
      return request.cookies
          .firstWhere((cookie) => cookie.name == inj.key, orElse: () => null)
          ?.value;
    } else if (inj is CookiesInject) {
      return request.cookies;
    } else if (inj is PathVarInject) {
      return convertPathVar(inj, pathParams);
    } else {
      throw new Exception('Unknown inject to post interceptor method!');
    }
  }

  factory ReflectedRoute.build(
      Function handler, j.RouteBase jRoute, List<j.RouteWrapper> wrappers) {
    final InstanceMirror im = reflect(handler);

    if (im is! ClosureMirror) {
      throw new Exception('Route handler must be a closure or function!');
    }

    final ClosureMirror c = im as ClosureMirror;
    final MethodMirror m = c.function;

    final List<Inject> required = _parseReqParamsForRoute(m);

    final Set<RouteQueryParam> optional = _parseOptParamsForRoute(m);

    final List<ReflectedInterceptor> interceptors = wrappers
        .map((j.RouteWrapper inter) => new ReflectedInterceptor.build(inter))
        .toList();

    return new ReflectedRoute(
        jRoute, handler, c, required, optional, interceptors);
  }
}