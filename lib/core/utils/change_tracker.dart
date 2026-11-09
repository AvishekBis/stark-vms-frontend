import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A counter bumped after every create / update / delete of one kind of
/// record. Providers that show those records watch it, so one bump
/// refreshes every list and the dashboard.
class ChangeTracker extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() => state++;
}

/// Bumped after any vehicle change (including status and assignments).
///
/// Declared here rather than in the vehicles feature because drivers and
/// assignments bump it too; this keeps the vehicles and drivers features
/// from importing each other's providers.
final vehicleChangesProvider = NotifierProvider<ChangeTracker, int>(
  ChangeTracker.new,
);

/// Bumped after any driver change (including assignments).
final driverChangesProvider = NotifierProvider<ChangeTracker, int>(
  ChangeTracker.new,
);
