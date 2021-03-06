part of jaguar_reflect.base;

class ReflectedInterceptor {
  final ReflectedWrapper wrapper;

  final j.Interceptor inter;

  final InstanceMirror interMirror;

  ReflectedInterceptor(this.wrapper, this.inter, this.interMirror);
}

class ReflectedRoute implements j.RequestHandler {
  final j.RouteBase route;

  final String prefix;

  final Function handler;

  final ClosureMirror _invoker;

  final List<Inject> _required;

  final Set<RouteQueryParam> _optional;

  final List<ReflectedWrapper> wrappers;

  ReflectedRoute(this.route, this.prefix, this.handler, this._invoker,
      this._required, this._optional, this.wrappers);

  Future<j.Response> handleRequest(j.Request request, {String prefix}) async {
    final j.PathParams pathParams = new j.PathParams();

    if (!route.match(request.uri.path, request.method, prefix, pathParams)) {
      return null;
    }

    final j.QueryParams queryParams =
        new j.QueryParams(request.uri.queryParameters);

    j.Response response = new j.Response(null,
        statusCode: route.statusCode, headers: route.headers);

    final List<ReflectedInterceptor> inters = [];
    final Map<InputInject, dynamic> results = {};
    try {
      for (ReflectedWrapper wrapper in wrappers) {
        final j.Interceptor i = wrapper.createInterceptor(
            request, response, results, pathParams, queryParams);
        final InstanceMirror im = reflect(i);
        final ReflectedInterceptor inter =
            new ReflectedInterceptor(wrapper, i, im);
        inters.add(inter);

        if (inter.wrapper._pre == null) continue;

        final List reqParam = [];

        for (Inject inj in inter.wrapper._pre.injects) {
          reqParam.add(_makeParam(
              inj, request, response, results, pathParams, queryParams));
        }

        dynamic result = inter.interMirror.invoke(#pre, reqParam).reflectee;
        if (result is Future) {
          result = await result;
        }
        InputInject key =
            new InputInject(wrapper.interceptorType, id: wrapper.id);
        results[key] = result;
      }

      {
        final List reqParam = [];
        for (Inject inj in _required) {
          reqParam.add(_makeParam(
              inj, request, response, results, pathParams, queryParams));
        }

        final Map<Symbol, dynamic> optParams = {};
        for (RouteQueryParam p in _optional) {
          optParams[new Symbol(p.key)] = convertQueryParam(p, queryParams);
        }

        dynamic result = _invoker.apply(reqParam, optParams).reflectee;
        if (result is Future) {
          result = await result;
        }
        if (result is j.Response) {
          response = result;
        } else {
          response.value = result;
        }
      }

      // Interceptors post
      for (ReflectedInterceptor inter in inters.reversed) {
        if (inter.wrapper._post == null) continue;

        final List reqParam = [];

        for (Inject inj in inter.wrapper._post.injects) {
          reqParam.add(_makeParam(
              inj, request, response, results, pathParams, queryParams));
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
      for (ReflectedInterceptor inter in inters.reversed) {
        await inter.inter.onException();
      }
      rethrow;
    }

    return response;
  }

  factory ReflectedRoute.build(Function handler, j.RouteBase jRoute,
      String prefix, List<j.RouteWrapper> wrappers, InstanceMirror groupIm) {
    final InstanceMirror im = reflect(handler);

    if (im is! ClosureMirror) {
      throw new Exception('Route handler must be a closure or function!');
    }

    final ClosureMirror c = im as ClosureMirror;
    final MethodMirror m = c.function;

    final List<Inject> required = _parseReqParamsForRoute(m);

    final Set<RouteQueryParam> optional = _parseOptParamsForRoute(m);

    final List<ReflectedWrapper> interceptors = wrappers
        .map((j.RouteWrapper inter) =>
            new ReflectedWrapper.build(inter, groupIm))
        .toList();

    return new ReflectedRoute(
        jRoute, prefix, handler, c, required, optional, interceptors);
  }
}

dynamic _makeParam(
    Inject inj,
    j.Request request,
    j.Response response,
    Map<InputInject, dynamic> interceptorResults,
    j.PathParams pathParams,
    j.QueryParams queryParams) {
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
  } else if (inj is QueryParamsInject) {
    return queryParams;
  } else if (inj is PathParamsInject) {
    return pathParams;
  } else {
    throw new Exception('Unknown inject to post interceptor method!');
  }
}

dynamic convertPathVar(PathVarInject info, j.PathParams pathParams) {
  switch (info.type) {
    case dynamic:
    case String:
      return pathParams.getField(info.key);
    case int:
      return pathParams.getFieldAsInt(info.key);
    case double:
      return pathParams.getFieldAsDouble(info.key);
    case num:
      return pathParams.getFieldAsNum(info.key);
    case bool:
      return pathParams.getFieldAsBool(info.key);
    default:
      throw new Exception('Unknown query parameter type!');
  }
}

dynamic convertQueryParam(RouteQueryParam info, j.QueryParams queryParams) {
  switch (info.type) {
    case dynamic:
    case String:
      return queryParams.getField(info.key);
    case int:
      return queryParams.getFieldAsInt(info.key);
    case double:
      return queryParams.getFieldAsDouble(info.key);
    case num:
      return queryParams.getFieldAsNum(info.key);
    case bool:
      return queryParams.getFieldAsBool(info.key);
    default:
      throw new Exception('Unknown query parameter type!');
  }
}
