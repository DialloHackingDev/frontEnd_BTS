import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

/// Observer pour logger les transitions de BLoC
/// Utile en développement pour debug
class SimpleBlocObserver extends BlocObserver {
  @override
  void onCreate(BlocBase bloc) {
    super.onCreate(bloc);
    if (kDebugMode) {
      print('🟢 BLoC Created: ${bloc.runtimeType}');
    }
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      print('🔄 BLoC Change: ${bloc.runtimeType}');
      print('   From: ${change.currentState}');
      print('   To: ${change.nextState}');
    }
  }
  
  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    if (kDebugMode) {
      print('➡️ BLoC Transition: ${bloc.runtimeType}');
      print('   Event: ${transition.event}');
      print('   From: ${transition.currentState}');
      print('   To: ${transition.nextState}');
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    if (kDebugMode) {
      print('❌ BLoC Error: ${bloc.runtimeType}');
      print('   Error: $error');
      print('   StackTrace: $stackTrace');
    }
  }

  @override
  void onClose(BlocBase bloc) {
    super.onClose(bloc);
    if (kDebugMode) {
      print('🔴 BLoC Closed: ${bloc.runtimeType}');
    }
  }
}
