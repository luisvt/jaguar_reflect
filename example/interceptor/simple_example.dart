import 'dart:async';
import 'package:jaguar_reflect/jaguar_reflect.dart';
import 'package:jaguar/jaguar.dart';

class WrapSampleInterceptor implements RouteWrapper<SampleInterceptor> {
  final String id = null;

  final Map<Symbol, MakeParam> makeParams;

  final String reqParam1;

  final int reqParam2;

  final String optParam1;

  final int optParam2;

  const WrapSampleInterceptor(this.reqParam1, this.reqParam2,
      {this.optParam1, this.optParam2, this.makeParams});

  SampleInterceptor createInterceptor() => new SampleInterceptor();
}

class SampleInterceptor extends Interceptor {
  void pre() {}
}

@Api()
class ExampleApi implements RequestHandler {
  JaguarReflected _reflected;

  ExampleApi() {
    _reflected = new JaguarReflected(this);
  }

  @Get(path: '/api/hello')
  @WrapSampleInterceptor('hello', 5, makeParams: const {
    #optParam2: 55,
  })
  Map sayHello() => {'hello': 'dart'};

  Future<Response> handleRequest(Request req, {String prefix}) =>
      _reflected.handleRequest(req, prefix: prefix);
}

main() async {
  final api = new ExampleApi();
}
