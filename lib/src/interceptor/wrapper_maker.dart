part of jaguar_reflect.base;

class MakeFromMethodHasInjection {
  final Symbol name;

  final List<Inject> injects;

  MakeFromMethodHasInjection(this.name, this.injects);

  factory MakeFromMethodHasInjection.build(MethodMirror m) {
    final List<Inject> injects = _parseReqParamsForPost(m);

    return new MakeFromMethodHasInjection(m.simpleName, injects);
  }
}

class WrapperMaker {
  final List<dynamic> posArgs;

  final Map<Symbol, dynamic> namedArgs;

  final ClassMirror _cm;

  final InstanceMirror _groupIm;

  WrapperMaker(this._cm, this.posArgs, this.namedArgs, this._groupIm);

  static const Symbol _emptySymbol = const Symbol('');

  j.RouteWrapper makeWrapper(
      j.Request request,
      j.Response response,
      Map<InputInject, dynamic> results,
      j.PathParams pathParams,
      j.QueryParams queryParams) {
    final List<dynamic> pos = [];

    final Map<Symbol, dynamic> named = {};

    for (dynamic p in posArgs) {
      if (p is j.MakeParamFromMethod) {
        pos.add(_groupIm.invoke(p.methodName, []).reflectee);
      } else if (p is j.MakeParamFromSettings) {
        pos.add(p.getSetting());
      } else if (p is MakeFromMethodHasInjection) {
        final List reqParam = [];
        for (Inject inj in p.injects) {
          reqParam.add(_makeParam(
              inj, request, response, results, pathParams, queryParams));
        }
        pos.add(_groupIm.invoke(p.name, reqParam).reflectee);
      } else {
        pos.add(p);
      }
    }

    for (Symbol k in namedArgs.keys) {
      dynamic p = namedArgs[k];
      if (p is j.MakeParamFromMethod) {
        named[k] = _groupIm.invoke(p.methodName, []).reflectee;
      } else if (p is j.MakeParamFromSettings) {
        named[k] = p.getSetting();
      } else if (p is MakeFromMethodHasInjection) {
        final List reqParam = [];
        for (Inject inj in p.injects) {
          reqParam.add(_makeParam(
              inj, request, response, results, pathParams, queryParams));
        }
        named[k] = _groupIm.invoke(p.name, reqParam).reflectee;
      } else {
        named[k] = p;
      }
    }

    return _cm.newInstance(_emptySymbol, pos, named).reflectee;
  }

  static WrapperMaker make(j.RouteWrapper wrapper, InstanceMirror groupIm) {
    //No need for wrapper maker if there are no makeParams
    if (wrapper.makeParams == null || wrapper.makeParams.isEmpty) return null;

    if (groupIm == null) {
      throw new Exception('makeParams cannot be used in this context!');
    }

    InstanceMirror im = reflect(wrapper);
    ClassMirror cm = im.type;

    MethodMirror constructor;

    final Map<String, VariableMirror> properties = {};

    // Find the unnamed constructor and all properties
    for (Symbol s in cm.declarations.keys) {
      DeclarationMirror dm = cm.declarations[s];
      if (dm is MethodMirror) {
        if (dm.isConstructor &&
            MirrorSystem.getName(dm.constructorName).isEmpty) {
          constructor = dm;
          break;
        }
      } else if (dm is VariableMirror) {
        properties[MirrorSystem.getName(s)] = dm;
      }
    }

    if (constructor == null) return null;

    List<dynamic> pos = [];
    Map<Symbol, dynamic> named = {};

    for (final ParameterMirror pm in constructor.parameters) {
      final String fieldName = MirrorSystem.getName(pm.simpleName);
      if (!properties.containsKey(fieldName)) {
        throw new Exception(
            "Wrapper constructor parameters must match properties!");
      }
      final reflectee = im.getField(pm.simpleName).reflectee;
      if (!pm.isOptional) {
        if (reflectee == null &&
            wrapper.makeParams.containsKey(pm.simpleName)) {
          final j.MakeParam makeParam = wrapper.makeParams[pm.simpleName];
          if (makeParam is j.MakeParamFromMethod) {
            final DeclarationMirror meth =
                groupIm.type.declarations[makeParam.methodName];
            if (meth is MethodMirror) {
              //TODO check if return type matches parameter type
              if (meth.parameters.length == 0) {
                pos.add(makeParam);
              } else {
                pos.add(new MakeFromMethodHasInjection.build(meth));
              }
            } else {
              throw new Exception("Method for MakeParamFromMethod not found!");
            }
          } else {
            pos.add(makeParam);
          }
        } else {
          pos.add(reflectee);
        }
      } else if (!pm.isNamed) {
        throw new Exception(
            'makeParams can only used with named optional parameters!');
      } else {
        if (wrapper.makeParams.containsKey(pm.simpleName)) {
          final j.MakeParam makeParam = wrapper.makeParams[pm.simpleName];
          if (makeParam is j.MakeParamFromMethod) {
            final DeclarationMirror meth =
                groupIm.type.declarations[makeParam.methodName];
            if (meth is MethodMirror) {
              //TODO check if return type matches parameter type
              if (meth.parameters.length == 0) {
                named[pm.simpleName] = makeParam;
              } else {
                named[pm.simpleName] =
                    new MakeFromMethodHasInjection.build(meth);
              }
            } else {
              throw new Exception("Method for MakeParamFromMethod not found!");
            }
          } else {
            named[pm.simpleName] = makeParam;
          }
        } else if (reflectee != pm.defaultValue.reflectee) {
          named[pm.simpleName] = reflectee;
        }
      }
    }

    return new WrapperMaker(cm, pos, named, groupIm);
  }
}
