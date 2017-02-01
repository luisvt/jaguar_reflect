part of jaguar_reflect.base;

List<Inject> detectInputs(final MethodMirror meth) {
  final List<Inject> ret = [];

  if (meth.parameters.length == 0) return ret;

  int paramIdx = 0;

  if (meth.parameters.length > 0) {
    if (meth.parameters.first.type.isSubtypeOf(reflectClass(j.Request))) {
      ret.add(new RequestInject());
      paramIdx++;
    }
  }

  for (int idx = 0; idx < meth.metadata.length; idx++) {
    final List annots = [];

    {
      dynamic annot = meth.metadata[idx].reflectee;
      if (_isInput(annot)) {
        annots.add(annot);
      } else {
        continue;
      }
    }

    if (paramIdx > meth.parameters.length) {
      throw new Exception("More Input than parameters!");
    }

    meth.parameters[paramIdx].metadata
        .map((InstanceMirror im) => im.reflectee)
        .forEach(annots.add);

    List<Inject> injects = _detectInjectsFromInputs(annots);

    paramIdx++;

    if (injects.length > 1) {
      throw new Exception("Only one Input allowed on a parameter!");
    } else if (injects.length == 0) {
      continue;
    }

    ret.add(injects.first);
  }

  bool finished = false;

  for (int idx = paramIdx; idx < meth.parameters.length; idx++) {
    final List annots = [];

    meth.parameters[paramIdx].metadata
        .map((InstanceMirror im) => im.reflectee)
        .forEach(annots.add);

    List<Inject> injects = _detectInjectsFromInputs(annots);

    paramIdx++;

    if (injects.length > 1) {
      throw new Exception("Only one Input allowed on a parameter!");
    } else if (injects.length == 0) {
      finished = true;
      continue;
    }

    if (finished) {
      throw new Exception(
          'Inputs must be specified on all consecutive parameters!');
    }

    ret.add(injects.first);
  }

  return ret;
}

bool _isInput(dynamic object) {
  if (object is j.Input) return true;
  if (object is j.InputHeader) return true;
  if (object is j.InputHeaders) return true;
  if (object is j.InputCookie) return true;
  if (object is j.InputCookies) return true;
  if (object is j.InputRouteResponse) return true;
  if (object is j.InputPathParams) return true;
  if (object is j.InputQueryParams) return true;

  return false;
}

List<Inject> _detectInjectsFromInputs(List annots) {
  return annots
      .where((dynamic annot) => _isInput(annot))
      .map(_detectInjectFromInput)
      .where((Inject inj) => inj is Inject)
      .toList();
}

Inject _detectInjectFromInput(annot) {
  if (annot is j.Input) return new InputInject(annot.resultFrom, id: annot.id);
  if (annot is j.InputHeader) return new HeaderInject(annot.key);
  if (annot is j.InputHeaders) return new HeadersInject();
  if (annot is j.InputCookie) return new CookieInject(annot.key);
  if (annot is j.InputCookies) return new CookiesInject();
  if (annot is j.InputRouteResponse) return new RouteResponseInject();

  return null;
}
