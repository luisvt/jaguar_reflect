part of jaguar_reflect.base;

abstract class Inject {}

class KeyedInject implements Inject {
  final String key;

  const KeyedInject(this.key);
}

class PathVarInject extends KeyedInject {
  final Type type;

  const PathVarInject(String key, this.type) : super(key);
}

class HeaderInject extends KeyedInject {
  const HeaderInject(String key) : super(key);
}

class HeadersInject implements Inject {
  const HeadersInject();
}

class CookieInject extends KeyedInject {
  const CookieInject(String key) : super(key);
}

class CookiesInject implements Inject {
  const CookiesInject();
}

class RouteResponseInject implements Inject {}

class RequestInject implements Inject {}

class InputInject implements Inject {
  /// Defines an interceptor, whose response must be used as input
  final Type resultFrom;

  /// Identifier to identify an interceptor from interceptors of same type
  final String id;

  const InputInject(this.resultFrom, {String id}) : id = id ?? '';

  bool operator ==(object) {
    if (object is! InputInject) return false;

    if (id != object.id) return false;

    if (resultFrom != object.resultFrom) return false;

    return true;
  }

  int get hashCode => hash2(resultFrom.toString(), id);
}

List<Inject> _parseReqParamsForRoute(final MethodMirror m) {
  final List<Inject> ret = detectInputs(m);

  for (int idx = ret.length; idx < m.parameters.length; idx++) {
    final ParameterMirror p = m.parameters[idx];

    if (p.isOptional) break;

    ret.add(new PathVarInject(
        MirrorSystem.getName(p.simpleName), p.type.reflectedType));
  }

  return ret;
}

class RouteQueryParam {
  final String key;

  final Type type;

  const RouteQueryParam(this.key, this.type);

  bool operator ==(object) {
    if (object is! RouteQueryParam) return false;

    return key == object.key;
  }

  int get hashCode => key.hashCode;
}

Set<RouteQueryParam> _parseOptParamsForRoute(final MethodMirror m) {
  final Set<RouteQueryParam> ret = new Set();

  for (ParameterMirror p in m.parameters) {
    if (!p.isOptional) continue;

    if (!p.isNamed) break;

    ret.add(new RouteQueryParam(
        MirrorSystem.getName(p.simpleName), p.type.reflectedType));
  }

  return ret;
}

List<Inject> _parseReqParamsForPost(final MethodMirror m) {
  return detectInputs(m);
}
