import 'sales_access_config.dart';

/// Resultado limpo da instalacao da carga local.
///
/// A action do FlutterFlow converte este objeto para `FirstAccessResultStruct`,
/// mantendo structs gerados fora das camadas de dominio e dados.
class SalesDatabaseInstallResult {
  const SalesDatabaseInstallResult({
    required this.message,
    this.config,
  });

  final String message;
  final SalesAccessConfig? config;
}
