class AppStats {
  const AppStats({
    required this.total,
    required this.completos,
    required this.pendientes,
    required this.duplicados,
    required this.listosExportar,
  });

  final int total;
  final int completos;
  final int pendientes;
  final int duplicados;
  final int listosExportar;
}
