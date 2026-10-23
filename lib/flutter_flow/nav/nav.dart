import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/admin/admin_utils.dart';
import '/auth/backend_auth/auth_util.dart';

import '/backend/push_notifications/push_notifications_handler.dart'
    show PushNotificationsHandler;
import '/main.dart';
import '/web_host_mode.dart';
import '/flutter_flow/flutter_flow_util.dart';

import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const Set<String> _cleanNavigationRouteNames = {
  'profile',
  'supportChat',
  'adminSupportChat',
  'adminSupportChats',
};

bool _isWebAdminPath(Uri uri) =>
    uri.path == AdminHomeWidget.routePath ||
    uri.path.startsWith('${AdminHomeWidget.routePath}/');

bool _isWebLoginPath(Uri uri) => uri.path == LoginWidget.routePath;

bool _shouldUseWebAdminMode(Uri uri) =>
    kIsWeb && (isWebAdminHost() || _isWebAdminPath(uri));

bool _hasWebAdminSession() =>
    isAdminPhone(currentPhoneNumber) || isAdminUser(currentUserDocument);

Widget _buildWebAwareEntryPage(AppStateNotifier appStateNotifier) {
  if (!kIsWeb) {
    return appStateNotifier.loggedIn ? NavBarPage() : LoginWidget();
  }
  if (!_shouldUseWebAdminMode(Uri.base)) {
    return appStateNotifier.loggedIn ? NavBarPage() : LoginWidget();
  }
  if (!appStateNotifier.loggedIn) {
    return LoginWidget();
  }
  return _hasWebAdminSession() ? const AdminHomeWidget() : LoginWidget();
}

String? _getWebAdminOnlyRedirect(
  AppStateNotifier appStateNotifier,
  GoRouterState state,
) {
  if (!kIsWeb || appStateNotifier.loading) {
    return null;
  }

  final isLoginPath = _isWebLoginPath(state.uri);
  final isAdminPath = _isWebAdminPath(state.uri);
  if (!_shouldUseWebAdminMode(state.uri)) {
    return null;
  }

  if (!appStateNotifier.loggedIn) {
    return isLoginPath ? null : LoginWidget.routePath;
  }

  final isAdminSession = _hasWebAdminSession();
  final hasResolvedSessionData =
      currentUserDocument != null || currentPhoneNumber.isNotEmpty;

  if (!isAdminSession && !hasResolvedSessionData) {
    return null;
  }

  if (!isAdminSession) {
    return isLoginPath ? null : LoginWidget.routePath;
  }

  return isAdminPath ? null : AdminHomeWidget.routePath;
}

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  /// Determines whether the app will refresh and build again when a sign
  /// in or sign out happens. This is useful when the app is launched or
  /// on an unexpected logout. However, this must be turned off when we
  /// intend to sign in/out and then navigate or perform any actions after.
  /// Otherwise, this will trigger a refresh and interrupt the action(s).
  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  /// Mark as not needing to notify on a sign in / out when we intend
  /// to perform subsequent actions (such as navigation) afterwards.
  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    // Refresh the app on auth change unless explicitly marked otherwise.
    // No need to update unless the user has changed.
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    // Once again mark the notifier as needing to update on auth change
    // (in order to catch sign in / out events).
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      redirect: (context, state) =>
          _getWebAdminOnlyRedirect(appStateNotifier, state),
      errorBuilder: (context, state) => RootPageContext.wrap(
        _buildWebAwareEntryPage(appStateNotifier),
        errorRoute: state.uri.toString(),
      ),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) => RootPageContext.wrap(
            _buildWebAwareEntryPage(appStateNotifier),
          ),
        ),
        FFRoute(
          name: HomePageWidget.routeName,
          path: HomePageWidget.routePath,
          builder: (context, params) => params.isEmpty
              ? NavBarPage(initialPage: 'HomePage')
              : HomePageWidget(),
        ),
        FFRoute(
          name: LoginWidget.routeName,
          path: LoginWidget.routePath,
          builder: (context, params) => LoginWidget(),
        ),
        FFRoute(
          name: SmsVireficationWidget.routeName,
          path: SmsVireficationWidget.routePath,
          builder: (context, params) => SmsVireficationWidget(),
        ),
        FFRoute(
          name: SetProfileWidget.routeName,
          path: SetProfileWidget.routePath,
          builder: (context, params) => SetProfileWidget(),
        ),
        FFRoute(
          name: CityToCityWidget.routeName,
          path: CityToCityWidget.routePath,
          builder: (context, params) => params.isEmpty
              ? NavBarPage(initialPage: 'HomePage')
              : HomePageWidget(),
        ),
        FFRoute(
          name: ProfileWidget.routeName,
          path: ProfileWidget.routePath,
          builder: (context, params) => params.isEmpty
              ? NavBarPage(initialPage: 'profile')
              : ProfileWidget(),
        ),
        FFRoute(
          name: SupportChatWidget.routeName,
          path: SupportChatWidget.routePath,
          builder: (context, params) => SupportChatWidget(),
        ),
        FFRoute(
          name: AdminSupportChatsWidget.routeName,
          path: AdminSupportChatsWidget.routePath,
          builder: (context, params) => AdminSupportChatsWidget(),
        ),
        FFRoute(
          name: AdminSupportChatWidget.routeName,
          path: AdminSupportChatWidget.routePath,
          builder: (context, params) => AdminSupportChatWidget(
            chatRef: params.getParam(
              'chatRef',
              ParamType.DocumentReference,
            ),
            chatDocPath: params.getParam<String>(
              'chatDocPath',
              ParamType.String,
            ),
            userRef: params.getParam(
              'userRef',
              ParamType.DocumentReference,
            ),
            userDocPath: params.getParam<String>(
              'userDocPath',
              ParamType.String,
            ),
            supportChatKey: params.getParam<String>(
              'supportChatKey',
              ParamType.String,
            ),
          ),
        ),
        FFRoute(
          name: AdminDriverStatsWidget.routeName,
          path: AdminDriverStatsWidget.routePath,
          builder: (context, params) => AdminDriverStatsWidget(),
        ),
        FFRoute(
          name: AdminMoneyStatsWidget.routeName,
          path: AdminMoneyStatsWidget.routePath,
          builder: (context, params) => const AdminMoneyStatsWidget(),
        ),
        FFRoute(
          name: SettingsWidget.routeName,
          path: SettingsWidget.routePath,
          builder: (context, params) => SettingsWidget(),
        ),
        FFRoute(
          name: MeOrderWidget.routeName,
          path: MeOrderWidget.routePath,
          builder: (context, params) => MeOrderWidget(),
        ),
        FFRoute(
          name: AboutWidget.routeName,
          path: AboutWidget.routePath,
          builder: (context, params) => AboutWidget(),
        ),
        FFRoute(
          name: PolitikaWidget.routeName,
          path: PolitikaWidget.routePath,
          builder: (context, params) => PolitikaWidget(),
        ),
        FFRoute(
          name: TarifWidget.routeName,
          path: TarifWidget.routePath,
          builder: (context, params) => TarifWidget(),
        ),
        FFRoute(
          name: SeachDriverWidget.routeName,
          path: SeachDriverWidget.routePath,
          builder: (context, params) => NavBarPage(
              initialPage: 'HomePage',
              page: SeachDriverWidget(
                orderDocPath: params.getParam<String>(
                  'orderDocPath',
                  ParamType.String,
                ),
              )),
        ),
        FFRoute(
          name: SetProfileDriverWidget.routeName,
          path: SetProfileDriverWidget.routePath,
          builder: (context, params) => SetProfileDriverWidget(),
        ),
        FFRoute(
          name: HomeDriverWidget.routeName,
          path: HomeDriverWidget.routePath,
          builder: (context, params) => NavBarPage(initialPage: 'driverOrders'),
        ),
        FFRoute(
          name: HomeDriverOrderWidget.routeName,
          path: HomeDriverOrderWidget.routePath,
          builder: (context, params) => NavBarPage(
              initialPage: 'driverOrders',
              page: HomeDriverOrderWidget(
                orderDocPath: params.getParam<String>(
                  'orderDocPath',
                  ParamType.String,
                ),
              )),
        ),
        FFRoute(
          name: AdminHomeWidget.routeName,
          path: AdminHomeWidget.routePath,
          requireAuth: true,
          builder: (context, params) => AdminHomeWidget(),
        ),
        FFRoute(
          name: AdminNotificationsWidget.routeName,
          path: AdminNotificationsWidget.routePath,
          requireAuth: true,
          builder: (context, params) => const AdminNotificationsWidget(),
        ),
        FFRoute(
          name: AdminCollectionWidget.routeName,
          path: AdminCollectionWidget.routePath,
          requireAuth: true,
          builder: (context, params) {
            final collectionName = params.getParam<String>(
                  'collection',
                  ParamType.String,
                ) ??
                '';
            return AdminCollectionWidget(collectionName: collectionName);
          },
        ),
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    // If there is only one route on the stack, navigate to the initial
    // page instead of popping.
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  // Parameters are empty if the params map is empty or if the only parameter
  // present is the special extra parameter reserved for the transition info.
  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    List<String>? collectionNamePath,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    // Got parameter from `extras`, so just directly return it.
    if (param is! String) {
      return param;
    }
    // Return serialized value.
    return deserializeParam<T>(
      param,
      type,
      isList,
      collectionNamePath: collectionNamePath,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }

          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/login';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);
          final child = appStateNotifier.loading
              ? const _MTaxiLoadingScreen()
              : PushNotificationsHandler(child: page);

          final transitionInfo = state.transitionInfo;
          if (_cleanNavigationRouteNames.contains(name)) {
            return NoTransitionPage(
              key: state.pageKey,
              child: child,
            );
          }
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: child,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(key: state.pageKey, child: child);
        },
        routes: routes,
      );
}

class _MTaxiLoadingScreen extends StatelessWidget {
  const _MTaxiLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final logoSize =
        (MediaQuery.sizeOf(context).width * 0.32).clamp(96.0, 132.0);

    return Scaffold(
      backgroundColor: const Color(0xFF12051B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.38),
                radius: 0.82,
                colors: [
                  Color(0x5531D8C6),
                  Color(0x22271334),
                  Color(0xFF12051B),
                ],
                stops: [0.0, 0.44, 1.0],
              ),
            ),
          ),
          Positioned(
            left: -88,
            top: -64,
            child: _SoftGlow(size: 210, color: Color(0x335B2C83)),
          ),
          Positioned(
            right: -74,
            bottom: -58,
            child: _SoftGlow(size: 220, color: Color(0x3328D8C6)),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B0B25),
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF28D8C6).withValues(alpha: 0.24),
                        blurRadius: 44,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/app_launcher_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'MTaxi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Подготавливаем поездку',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 26),
                const SizedBox(
                  width: 156,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: Color(0xFF28D8C6),
                    backgroundColor: Color(0x3328D8C6),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 70,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
