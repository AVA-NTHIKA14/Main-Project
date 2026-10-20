import 'package:flutter/foundation.dart';

enum PermissionType { location, motion, notifications }

enum PermissionState {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

abstract interface class PermissionService {
  Future<PermissionState> status(PermissionType permission);
  Future<PermissionState> request(PermissionType permission);
  Future<bool> openSettings();
}

class MockPermissionService implements PermissionService {
  MockPermissionService({Map<PermissionType, PermissionState>? initialStates})
    : _states = {
        for (final permission in PermissionType.values)
          permission:
              initialStates?[permission] ?? PermissionState.notRequested,
      };

  final Map<PermissionType, PermissionState> _states;

  @override
  Future<PermissionState> status(PermissionType permission) async =>
      _states[permission] ?? PermissionState.notRequested;

  @override
  Future<PermissionState> request(PermissionType permission) async {
    final current = await status(permission);
    if (current == PermissionState.notRequested ||
        current == PermissionState.denied) {
      _states[permission] = PermissionState.granted;
    }
    return status(permission);
  }

  @override
  Future<bool> openSettings() async => true;
}

class PermissionController extends ChangeNotifier {
  PermissionController({required this._service});

  final PermissionService _service;
  final Map<PermissionType, PermissionState> _states = {};

  PermissionState stateFor(PermissionType permission) =>
      _states[permission] ?? PermissionState.notRequested;

  Future<PermissionState> request(PermissionType permission) async {
    final state = await _service.request(permission);
    _states[permission] = state;
    notifyListeners();
    return state;
  }

  Future<void> load(PermissionType permission) async {
    _states[permission] = await _service.status(permission);
    notifyListeners();
  }

  Future<bool> openSettings() => _service.openSettings();
}

String permissionStateLabel(PermissionState state) => switch (state) {
  PermissionState.notRequested => 'Not requested',
  PermissionState.granted => 'Allowed',
  PermissionState.denied => 'Not allowed',
  PermissionState.permanentlyDenied => 'Blocked in settings',
  PermissionState.restricted => 'Restricted',
  PermissionState.unavailable => 'Unavailable on this device',
};
