part of jaguar_reflect.base;

class _Pre {
  final List<Inject> injects;

  _Pre(this.injects);

  factory _Pre.build(MethodMirror m) {
    final List<Inject> injects = _parseReqParamsForPost(m);

    return new _Pre(injects);
  }
}

class _Post {
  final List<Inject> injects;

  _Post(this.injects);

  factory _Post.build(MethodMirror m) {
    final List<Inject> injects = _parseReqParamsForPost(m);

    return new _Post(injects);
  }
}

class ReflectedWrapper {
  final j.RouteWrapper routeWrapper;

  final Type interceptorType;

  final _Pre _pre;

  final _Post _post;

  ReflectedWrapper(
      this.routeWrapper, this._pre, this._post, this.interceptorType);

  factory ReflectedWrapper.build(j.RouteWrapper wrapper) {
    ClassMirror icm = _getInterceptorMirror(wrapper);
    _Pre pre;
    _Post post;
    DeclarationMirror preM = icm.declarations[#pre];
    if (preM is MethodMirror) {
      pre = new _Pre.build(preM);
    }
    DeclarationMirror postM = icm.declarations[#post];
    if (postM is MethodMirror) {
      post = new _Post.build(postM);
    }

    return new ReflectedWrapper(wrapper, pre, post, icm.reflectedType);
  }

  static ClassMirror _getInterceptorMirror(final j.RouteWrapper wrapper) {
    final ClassMirror cm = reflectClass(wrapper.runtimeType);
    final List<ClassMirror> wcms = cm.superinterfaces.where((ClassMirror inm) {
      ClassMirror rhs = reflectClass(j.RouteWrapper);
      return inm.qualifiedName == rhs.qualifiedName;
    }).toList();

    if (wcms.length == 0) {
      throw new Exception('Wrapper must be a subclass of RouteWrapper!');
    } else if (wcms.length > 1) {
      throw new Exception(
          'Wrapper must be subclassed from RouteWrapper only once!');
    }

    final ClassMirror wcm = wcms.first;
    if (wcm.typeArguments.length != 1) {
      throw new Exception(
          'Interceptor type must be specified in RouteWrapper type argument!');
    }

    return wcm.typeArguments.first;
  }
}
