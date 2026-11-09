/// Direction part of the `sort=field,direction` query parameter.
enum SortDirection {
  ascending('asc'),
  descending('desc');

  const SortDirection(this.apiValue);

  final String apiValue;

  SortDirection get reversed => this == SortDirection.ascending
      ? SortDirection.descending
      : SortDirection.ascending;
}
