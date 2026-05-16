bool isVersionLower(String current, String minimum) {
  final a = _parse(current);
  final b = _parse(minimum);
  for (var i = 0; i < b.length; i++) {
    final aVal = i < a.length ? a[i] : 0;
    if (aVal < b[i]) return true;
    if (aVal > b[i]) return false;
  }
  return false;
}

List<int> _parse(String version) {
  final clean = version.split('+').first.split('-').first;
  return clean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
}
