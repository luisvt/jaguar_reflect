import 'dart:math';
import 'package:jaguar_reflect/jaguar_reflect.dart';
import 'package:jaguar/jaguar.dart';

final _random = new Random.secure();

class WrapRandomNumberGen implements RouteWrapper<RandomNumberGen> {
  String get id => null;

  Map<Symbol, MakeParam> get makeParams => null;

  const WrapRandomNumberGen();

  RandomNumberGen createInterceptor() => new RandomNumberGen();
}

class RandomNumberGen extends Interceptor {
  int pre() => _random.nextInt(1000);
}

class WrapSampleInterceptor implements RouteWrapper<SampleInterceptor> {
  final String id = null;

  final Map<Symbol, MakeParam> makeParams;

  final String reqParam1;

  final int reqParam2;

  final String optParam1;

  final int optParam2;

  const WrapSampleInterceptor(this.reqParam1, this.reqParam2,
      {this.optParam1, this.optParam2, this.makeParams});

  SampleInterceptor createInterceptor() =>
      new SampleInterceptor(reqParam2, optParam2);
}

class SampleInterceptor extends Interceptor {
  final int reqParam2;
  final int optParam2;

  SampleInterceptor(this.reqParam2, this.optParam2);

  int pre() => optParam2;
}

@Api(path: '/api')
class ExampleApi {
  @Get(path: '/hello')
  @WrapRandomNumberGen()
  @WrapSampleInterceptor('hello', 5, makeParams: const {
    #optParam2: const MakeParamFromMethod(#getParam2),
  })
  Map sayHello(@Input(SampleInterceptor) int number) => {'hello': number};

  int getParam2(@Input(RandomNumberGen) int number) => number * 2;
}

main() async {
  final api = new ExampleApi();

  final conf = new Configuration();
  conf.addApi(reflectJaguar(api));
  await serve(conf);
}
