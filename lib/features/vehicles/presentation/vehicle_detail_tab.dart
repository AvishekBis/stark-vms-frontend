/// The tabs of the vehicle detail screen (guideline 14.1), addressable as
/// `/vehicles/:id?tab=documents`.
enum VehicleDetailTab {
  overview('overview', 'Overview'),
  documents('documents', 'Documents'),
  maintenance('maintenance', 'Maintenance'),
  drivers('drivers', 'Driver history');

  const VehicleDetailTab(this.queryValue, this.label);

  final String queryValue;
  final String label;

  /// Unknown or missing values open the overview.
  static VehicleDetailTab fromQuery(String? value) {
    for (final tab in values) {
      if (tab.queryValue == value?.toLowerCase()) {
        return tab;
      }
    }
    return VehicleDetailTab.overview;
  }
}
