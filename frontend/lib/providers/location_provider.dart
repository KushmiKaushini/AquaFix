import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/location_constants.dart';

class LocationState {
  final bool isLoading;
  final Position? position;
  final String? errorMessage;
  final DateTime? fetchedAt;

  LocationState({
    this.isLoading = false,
    this.position,
    this.errorMessage,
    this.fetchedAt,
  });

  LocationState copyWith({
    bool? isLoading,
    Position? position,
    String? errorMessage,
    DateTime? fetchedAt,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      errorMessage: errorMessage ?? this.errorMessage,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  /// Check if location is still fresh (within cache duration)
  bool get isLocationFresh {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt!) <
        LocationConstants.cacheDuration;
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier() : super(LocationState());

  /// Fetch location with intelligent caching
  Future<void> fetchLocation({bool forceRefresh = false}) async {
    // Return cached location if fresh and not forcing refresh
    if (!forceRefresh && state.position != null && state.isLocationFresh) {
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Location services are disabled. Please enable them in your device settings.',
        );
        return;
      }

      // 2. Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'Location permission denied. Unable to capture coordinates.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Location permissions are permanently denied. Please enable them in app settings.',
        );
        return;
      }

      // 3. Try to get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: LocationConstants.gpsTimeout,
      );

      state = state.copyWith(
        isLoading: false,
        position: position,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error capturing GPS coordinate: ${e.toString()}',
      );
    }
  }

  /// Clear location data
  void clearLocation() {
    state = LocationState();
  }
}

/// Riverpod provider for location state
final locationProvider = StateNotifierProvider<LocationNotifier, LocationState>(
  (ref) => LocationNotifier(),
);
