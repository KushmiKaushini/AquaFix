import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';

/// Provides app configuration
final appConfigProvider = Provider<AppConfig>((ref) {
  return getAppConfig();
});

/// Provides authentication service
final authServiceProvider = Provider<AuthService>((ref) {
  final config = ref.watch(appConfigProvider);
  return AuthService(config: config);
});

/// Provides API service
final apiServiceProvider = Provider<ApiService>((ref) {
  final config = ref.watch(appConfigProvider);
  final authService = ref.watch(authServiceProvider);
  return ApiService(
    config: config,
    authService: authService,
  );
});

/// Auth state provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService);
});

/// Incidents list state provider
final incidentsProvider = StateNotifierProvider<IncidentsNotifier, IncidentsState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return IncidentsNotifier(apiService);
});

/// Selected incident provider for detail view
final selectedIncidentProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// State classes
class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? user;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.user,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? user,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _authService.login(email: email, password: password);
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        user: result,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> register(String email, String password, String fullName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      // Auto-login after registration
      await login(email, password);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class IncidentsState {
  final List<Map<String, dynamic>> incidents;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int total;
  final int skip;
  final int limit;
  final bool hasMore;

  IncidentsState({
    this.incidents = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.total = 0,
    this.skip = 0,
    this.limit = 20,
    this.hasMore = true,
  });

  IncidentsState copyWith({
    List<Map<String, dynamic>>? incidents,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? total,
    int? skip,
    int? limit,
    bool? hasMore,
  }) {
    return IncidentsState(
      incidents: incidents ?? this.incidents,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      total: total ?? this.total,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class IncidentsNotifier extends StateNotifier<IncidentsState> {
  final ApiService _apiService;

  IncidentsNotifier(this._apiService) : super(IncidentsState());

  Future<void> fetchIncidents({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, error: null, skip: 0);
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final result = await _apiService.getIncidents(
        skip: refresh ? 0 : state.skip,
        limit: state.limit,
      );

      final items = (result['items'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [];
      final total = result['total'] ?? 0;

      if (refresh) {
        state = state.copyWith(
          incidents: items,
          total: total,
          skip: state.limit,
          isLoading: false,
          hasMore: items.length < total,
        );
      } else {
        state = state.copyWith(
          incidents: [...state.incidents, ...items],
          skip: state.skip + state.limit,
          isLoadingMore: false,
          hasMore: (state.incidents.length + items.length) < total,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.isLoadingMore && state.hasMore) {
      await fetchIncidents(refresh: false);
    }
  }
}
