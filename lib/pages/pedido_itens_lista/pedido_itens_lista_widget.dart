import 'dart:async';
import '/action_code/index.dart';
import '/functions/proximo_numero_pedido.dart';
import '/backend/schema/structs/index.dart';
import '/core/app_theme.dart';
import '/core/app_icon_button.dart';
import '/core/app_util.dart';
import '/index.dart';
import '/domain/services/valide_pco_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pedido_itens_lista_model.dart';
import '/functions/resolver_cod_filial.dart';
import '/functions/format_quantity.dart';
import '/data/services/local_sales_database_service.dart';
import '/components/bottom_sheet_selecao_bonificacao/bottom_sheet_selecao_bonificacao_widget.dart';
import '/components/bottom_sheet_combos/bottom_sheet_combos_widget.dart';
import '/components/modal_agente_cobrador/modal_agente_cobrador_widget.dart';
import '/components/modal_observacao_pedido/modal_observacao_pedido_widget.dart';
import 'widgets/item_pedido_card_widget.dart';
export 'pedido_itens_lista_model.dart';

class PedidoItensListaWidget extends StatefulWidget {
  const PedidoItensListaWidget({
    super.key,
    required this.pedidoId,
    required this.clienteNome,
    required this.clienteCodigo,
    required this.linhaCodigo,
    required this.planoCodigo,
    this.clienteCnpj,
    this.clienteCidade,
    this.clienteLimite,
    this.linhaDescricao,
    this.planoDescricao,
    this.clienteEndereco,
  });

  final int? pedidoId;
  final String? clienteNome;
  final int? clienteCodigo;
  final String? linhaCodigo;
  final String? planoCodigo;
  final String? clienteCnpj;
  final String? clienteCidade;
  final String? clienteLimite;
  final String? linhaDescricao;
  final String? planoDescricao;
  final String? clienteEndereco;

  static String routeName = 'PedidoItensLista';
  static String routePath = '/pedidoItensLista';

  @override
  State<PedidoItensListaWidget> createState() => _PedidoItensListaWidgetState();
}

class _PedidoItensListaWidgetState extends State<PedidoItensListaWidget> {
  late PedidoItensListaModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _debounceTimer;

  String? _currentPlanoCodigo;
  String? _currentPlanoDescricao;
  String? _currentLinhaCodigo;
  String? _currentLinhaDescricao;
  String? _clienteNome;
  int? _clienteCodigo;
  String? _clienteCnpj;
  String? _clienteCidade;
  String? _clienteLimite;
  String? _clienteEndereco;
  bool _pedidoDigitado = false; // PRD C2 — trava grid quando sttdig==DIGITADO
  bool _chkBonFrcVen = false; // PRD C3 — chk_bonfrcven
  bool _carregandoItens = true; // Impede auto-save prematuro durante carga inicial

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PedidoItensListaModel());
    _currentPlanoCodigo = widget.planoCodigo;
    _currentPlanoDescricao = widget.planoDescricao;
    _currentLinhaCodigo = widget.linhaCodigo;
    _currentLinhaDescricao = widget.linhaDescricao;
    _clienteNome = widget.clienteNome;
    _clienteCodigo = widget.clienteCodigo;
    _clienteCnpj = widget.clienteCnpj;
    _clienteCidade = widget.clienteCidade;
    _clienteLimite = widget.clienteLimite;
    _clienteEndereco = widget.clienteEndereco;

    if (widget.pedidoId != null && widget.pedidoId != 0) {
      AppState().pedido_numero = widget.pedidoId!;
    }

    // Trigger initial search for all products
    _searchProducts('');
    _inicializarDadosPedido();
  }

  Future<void> _inicializarDadosPedido() async {
    _carregandoItens = true;
    try {
      await _carregarDadosPedidoECliente();
      await _carregarSttDig();
      await _carregarItensExistentes();
    } finally {
      if (mounted) {
        setState(() => _carregandoItens = false);
      } else {
        _carregandoItens = false;
      }
    }
  }

  Future<void> _carregarDadosPedidoECliente() async {
    final pedId = widget.pedidoId ?? 0;
    if (pedId == 0) return;
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      final rows = await db.rawQuery(
        'SELECT * FROM pckvendig000 WHERE ped00_numped = ? LIMIT 1',
        [pedId],
      );
      if (rows.isNotEmpty) {
        final r = rows.first;
        final cliCod = (r['ped00_codcli'] is num) ? (r['ped00_codcli'] as num).toInt() : (int.tryParse(r['ped00_codcli']?.toString() ?? '') ?? 0);
        final cliDes = r['ped00_clides']?.toString() ?? '';
        final linCod = r['ped00_codlin']?.toString() ?? '';
        final linDes = r['ped00_lindes']?.toString() ?? '';
        final plaCod = r['ped00_codpla']?.toString() ?? '';
        final plaDes = r['ped00_plades']?.toString() ?? '';

        if ((_clienteCodigo == null || _clienteCodigo == 0) && cliCod != 0) {
          _clienteCodigo = cliCod;
        }
        if ((_clienteNome == null || _clienteNome!.isEmpty) && cliDes.isNotEmpty) {
          _clienteNome = cliDes;
        }
        if ((_currentLinhaCodigo == null || _currentLinhaCodigo!.isEmpty) && linCod.isNotEmpty) {
          _currentLinhaCodigo = linCod;
        }
        if ((_currentLinhaDescricao == null || _currentLinhaDescricao!.isEmpty) && linDes.isNotEmpty) {
          _currentLinhaDescricao = linDes;
        }
        if ((_currentPlanoCodigo == null || _currentPlanoCodigo!.isEmpty) && plaCod.isNotEmpty) {
          _currentPlanoCodigo = plaCod;
        }
        if ((_currentPlanoDescricao == null || _currentPlanoDescricao!.isEmpty) && plaDes.isNotEmpty) {
          _currentPlanoDescricao = plaDes;
        }

        // Se linhaDescricao ainda estiver vazia mas linhaCodigo estiver presente, busca em cadlin00
        if ((_currentLinhaDescricao == null || _currentLinhaDescricao!.isEmpty) && (_currentLinhaCodigo != null && _currentLinhaCodigo!.isNotEmpty)) {
          try {
            final lr = await db.rawQuery('SELECT lin00_descri FROM cadlin00 WHERE lin00_codigo = ? LIMIT 1', [_currentLinhaCodigo]);
            if (lr.isNotEmpty) {
              _currentLinhaDescricao = lr.first['lin00_descri']?.toString() ?? '';
            }
          } catch (_) {}
        }

        // Se planoDescricao ainda estiver vazia mas planoCodigo estiver presente, busca em cadpla00
        if ((_currentPlanoDescricao == null || _currentPlanoDescricao!.isEmpty) && (_currentPlanoCodigo != null && _currentPlanoCodigo!.isNotEmpty)) {
          try {
            final pr = await db.rawQuery('SELECT pla00_descri FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [_currentPlanoCodigo]);
            if (pr.isNotEmpty) {
              _currentPlanoDescricao = pr.first['pla00_descri']?.toString() ?? '';
            }
          } catch (_) {}
        }

        // Busca dados cadastrais completos do cliente em cadcli00
        final effectiveCli = _clienteCodigo ?? cliCod;
        if (effectiveCli != 0) {
          try {
            final cr = await db.rawQuery('SELECT * FROM cadcli00 WHERE cli00_codigo = ? LIMIT 1', [effectiveCli]);
            if (cr.isNotEmpty) {
              final cMap = cr.first;
              if (_clienteNome == null || _clienteNome!.isEmpty) {
                _clienteNome = cMap['cli00_descri']?.toString() ?? cMap['cli00_fantasi']?.toString() ?? cMap['cli00_fantas']?.toString() ?? cMap['descri']?.toString() ?? '';
              }
              if (_clienteCnpj == null || _clienteCnpj!.isEmpty) {
                _clienteCnpj = cMap['cli00_cpfcnp']?.toString() ?? cMap['cli00_cgc']?.toString() ?? cMap['cli00_cpf']?.toString() ?? cMap['cli00_cnpj']?.toString() ?? cMap['cpfcnp']?.toString() ?? '';
              }
              if (_clienteCidade == null || _clienteCidade!.isEmpty) {
                final cid = cMap['cli00_ciddes']?.toString() ?? cMap['cli00_cidade']?.toString() ?? cMap['cli00_cidcod']?.toString() ?? cMap['cidade']?.toString() ?? '';
                final uf = cMap['cli00_estsgl']?.toString() ?? cMap['cli00_uf']?.toString() ?? cMap['uf']?.toString() ?? '';
                if (cid.isNotEmpty && uf.isNotEmpty) {
                  _clienteCidade = '$cid - $uf';
                } else if (cid.isNotEmpty) {
                  _clienteCidade = cid;
                }
              }
              if (_clienteEndereco == null || _clienteEndereco!.isEmpty) {
                final end = cMap['cli00_endere']?.toString() ?? cMap['cli00_endereco']?.toString() ?? cMap['endereco']?.toString() ?? '';
                final num = cMap['cli00_endnum']?.toString() ?? cMap['numero']?.toString() ?? '';
                final bai = cMap['cli00_bairro']?.toString() ?? cMap['bairro']?.toString() ?? '';
                String fullEnd = end;
                if (num.isNotEmpty) fullEnd += ', $num';
                if (bai.isNotEmpty) fullEnd += ' - $bai';
                _clienteEndereco = fullEnd;
              }
              if (_clienteLimite == null || _clienteLimite!.isEmpty) {
                final limVal = cMap['cli00_crelim'] ?? cMap['cli00_limite'] ?? cMap['cli00_limcre'] ?? cMap['limite'];
                final lim = (limVal is num) ? limVal.toDouble() : (double.tryParse(limVal?.toString() ?? '') ?? 0.0);
                if (lim > 0) {
                  _clienteLimite = lim.toMoeda(incluirSimbolo: false);
                }
              }
            }
          } catch (_) {}
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      print('Erro ao carregar dados do pedido e cliente: $e');
    }
  }

  Future<void> _carregarItensExistentes() async {
    final pedId = widget.pedidoId ?? 0;
    if (pedId == 0) return;
    try {
      final db = await LocalSalesDatabaseService.getDatabase();
      final tHeader = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND lower(name)='pckvendig010'");
      if (tHeader.isEmpty) return;

      final cols = await db.rawQuery('PRAGMA table_info(pckvendig010)');
      final colNames = cols.map((r) => r['name']?.toString().toLowerCase()).toSet();

      String colNum = 'ped10_numped';
      for (final c in ['ped10_numped', 'ped10_pedcod', 'ped10_codmov', 'numped']) {
        if (colNames.contains(c)) { colNum = c; break; }
      }

      final rows = await db.rawQuery('SELECT * FROM pckvendig010 WHERE $colNum = ?', [pedId]);
      if (rows.isNotEmpty) {
        final List<ItemPedidoStruct> carregados = [];
        for (final r in rows) {
          final isBon = (r['ped10_sttbon'] == 1 || r['ped10_flgbon'] == 1 || r['ped10_bonificado'] == 1);
          final qtd = (r['ped10_qtdped'] is num) ? (r['ped10_qtdped'] as num).toDouble() : (double.tryParse(r['ped10_qtdped']?.toString() ?? '') ?? 0.0);
          final qtdBon = (r['ped10_qtdbon'] is num) ? (r['ped10_qtdbon'] as num).toDouble() : (double.tryParse(r['ped10_qtdbon']?.toString() ?? '') ?? 0.0);
          final pco = (r['ped10_pcosub'] is num)
              ? (r['ped10_pcosub'] as num).toDouble()
              : (r['ped10_prcuni'] is num)
                  ? (r['ped10_prcuni'] as num).toDouble()
                  : (r['ped10_vlruni'] is num)
                      ? (r['ped10_vlruni'] as num).toDouble()
                      : (double.tryParse(r['ped10_pcosub']?.toString() ?? r['ped10_prcuni']?.toString() ?? r['ped10_vlruni']?.toString() ?? '') ?? 0.0);

          double tot = (r['ped10_totprd'] is num)
              ? (r['ped10_totprd'] as num).toDouble()
              : (r['ped10_totite'] is num)
                  ? (r['ped10_totite'] as num).toDouble()
                  : (r['ped10_valtot'] is num)
                      ? (r['ped10_valtot'] as num).toDouble()
                      : (double.tryParse(r['ped10_totprd']?.toString() ?? r['ped10_totite']?.toString() ?? r['ped10_valtot']?.toString() ?? '') ?? 0.0);

          if (tot == 0.0 && !isBon && qtd > 0 && pco > 0) {
            tot = qtd * pco;
          }

          String codPrd = r['ped10_codprd']?.toString() ?? r['ped10_codpro']?.toString() ?? r['ped10_procod']?.toString() ?? '';
          String descri = r['ped10_descri']?.toString() ?? r['ped10_descricao']?.toString() ?? r['ped10_prodes']?.toString() ?? '';
          String unid = r['ped10_unidpri']?.toString() ?? r['ped10_unidade']?.toString() ?? r['ped10_unimed']?.toString() ?? 'UN';

          String marca = '';
          String ref1 = '';
          String ref2 = '';
          String codbar = '';
          String embalagem = '';

          // Busca dados detalhados (marca, referências, EAN, embalagem) em cadpro00 + cadmar00 com suporte a bancos legados
          if (codPrd.isNotEmpty) {
            try {
              final pr = await db.rawQuery('SELECT * FROM cadpro00 WHERE pro00_codigo = ? OR CAST(pro00_codigo AS TEXT) = ? LIMIT 1', [codPrd, codPrd]);
              if (pr.isNotEmpty) {
                final pRow = pr.first;
                if (descri.isEmpty) {
                  descri = pRow['pro00_descri']?.toString() ?? pRow['descri']?.toString() ?? '';
                }
                if (unid == 'UN') {
                  final u = pRow['pro00_unimed']?.toString() ?? pRow['pro00_unidade']?.toString() ?? pRow['pro00_unidad']?.toString() ?? '';
                  if (u.isNotEmpty) unid = u;
                }
                ref1 = pRow['pro00_ref001']?.toString() ?? '';
                ref2 = pRow['pro00_ref002']?.toString() ?? '';
                codbar = pRow['pro00_codbar']?.toString() ?? '';
                embalagem = pRow['pro00_embala']?.toString() ?? unid;

                final codMar = pRow['pro00_codmar'];
                if (codMar != null) {
                  try {
                    final mr = await db.rawQuery('SELECT mar00_descri FROM cadmar00 WHERE mar00_codigo = ? LIMIT 1', [codMar]);
                    if (mr.isNotEmpty) {
                      marca = mr.first['mar00_descri']?.toString() ?? '';
                    } else {
                      final mr2 = await db.rawQuery('SELECT mar00_descri FROM mar00 WHERE mar00_codigo = ? LIMIT 1', [codMar]);
                      if (mr2.isNotEmpty) {
                        marca = mr2.first['mar00_descri']?.toString() ?? '';
                      }
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }

          final refs = <String>[];
          if (ref1.trim().isNotEmpty) refs.add(ref1.trim());
          if (ref2.trim().isNotEmpty) refs.add(ref2.trim());
          final referenciaFormatada = refs.isNotEmpty ? refs.join(' / ') : '';

          final codCmb = r['ped10_codcmb']?.toString() ?? r['ped10_combo']?.toString() ?? '';

          carregados.add(ItemPedidoStruct(
            codigoProduto: codPrd,
            descricao: descri,
            unidade: unid.isNotEmpty ? unid : 'UN',
            quantidade: isBon ? 0.0 : qtd,
            precoUnitario: pco,
            totalItem: isBon ? 0.0 : tot,
            isBonificacao: isBon,
            quantidadeBonificada: isBon ? (qtdBon > 0 ? qtdBon : qtd) : 0.0,
            codigoCombo: codCmb,
            unidadeComercial: isBon ? (qtdBon > 0 ? qtdBon : qtd) : qtd,
            mulver: 1.0,
            embalagem: embalagem.isNotEmpty ? embalagem : unid,
            marca: marca,
            referencia: referenciaFormatada,
            codbar: codbar,
          ));
        }
        if (mounted) {
          safeSetState(() {
            _model.carrinhoItens = carregados;
            _model.recalcularTotais();
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar itens existentes do pedido: $e');
    }
  }

  Future<void> _autoSalvarCarrinho() async {
    if (_carregandoItens || _pedidoDigitado) return; // Não sobrescreve se ainda estiver carregando ou pedido concluído
    final pedId = widget.pedidoId ?? 0;
    final cliCod = _clienteCodigo ?? widget.clienteCodigo ?? 0;
    if (pedId == 0 || cliCod == 0) return;
    try {
      await salvarCarrinhoPedido(
        pedidoId: pedId,
        clienteCodigo: cliCod,
        linhaCodigo: _currentLinhaCodigo,
        planoCodigo: _currentPlanoCodigo,
        carrinhoItens: _model.carrinhoItens,
        bonfrcven: _chkBonFrcVen ? 1 : 0,
      );
    } catch (e) {
      print('Erro auto-save carrinho: $e');
    }
  }

  Future<void> _carregarSttDig() async {
    try {
      // Usa o singleton ativo — sem abrir conexão descartável read-only
      final db = await LocalSalesDatabaseService.getDatabase();
      final cols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
      final cn = cols.map((r) => r['name'].toString().toLowerCase()).toSet();
      if (cn.contains('ped00_sttdig')) {
        final rows = await db.rawQuery('SELECT ped00_sttdig FROM pckvendig000 WHERE ped00_numped = ? LIMIT 1', [widget.pedidoId ?? 0]);
        if (rows.isNotEmpty) {
          final v = rows.first['ped00_sttdig'];
          final iv = v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
          if (iv == 1) {
            if (mounted) setState(() => _pedidoDigitado = true);
          } else {
            if (mounted) setState(() => _pedidoDigitado = false);
          }
        }
      }
    } catch (_) {}
  }

  bool _isEdicaoBloqueada() {
    if (_pedidoDigitado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido já digitado — reabertura necessária para edição. (TODO PedidosRascunhosPageWidget)')),
      );
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (!_carregandoItens && !_pedidoDigitado) {
      _autoSalvarCarrinho();
    }
    _model.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    safeSetState(() {
      _model.isLoading = true;
    });

    try {
      // Calls existing buscaProduto action with active filial and active price table
      final int tabId = int.tryParse(_currentPlanoCodigo ?? widget.planoCodigo ?? '0') ?? 0;
      final int filial = AppState().codFilialAtiva != 0 ? AppState().codFilialAtiva : 1;
      final results = await buscaProduto(
        query,
        null,
        null,
        null,
        null,
        null,
        false,
        false,
        filial,
        'Todas',
        tabId,
      );

      safeSetState(() {
        _model.produtosPesquisados = results;
      });
    } catch (e) {
      print('Erro ao buscar produtos: $e');
    } finally {
      safeSetState(() {
        _model.isLoading = false;
      });
    }
  }

  ItemPedidoStruct? _findCartItem(String codigoProduto) {
    for (final item in _model.carrinhoItens) {
      if (item.codigoProduto == codigoProduto) return item;
    }
    return null;
  }

  Future<double> _getSaldoEstoque(String codigoProduto) async {
    // PRD B4: respeita ven00_chkest — se 0, estoque não é validado
    if (AppState().ven_chkest == 0) return 999999.0;
    double saldo = 0.0;
    try {
      // Usa o singleton ativo — sem abrir conexão descartável
      final db = await LocalSalesDatabaseService.getDatabase();
      final fil = AppState().codFilialAtiva != 0
          ? AppState().codFilialAtiva
          : (resolverCodFilial(AppState().empresa_codigo) ?? 1);
      final results = await db.rawQuery(
        "SELECT (COALESCE(pro00_qtdest, 0) - COALESCE(pro00_qtdpen, 0)) AS saldo "
        "FROM estpro00 WHERE (pro00_codpro = ? OR pro00_codpro = CAST(? AS TEXT)) "
        "AND (pro00_codfil = ? OR pro00_codfil = ? OR CAST(pro00_codfil AS INTEGER) = ?)",
        [codigoProduto, codigoProduto, fil, fil.toString().padLeft(2, '0'), fil]
      );
      if (results.isNotEmpty) {
        final val = results.first['saldo'];
        if (val is num) {
          saldo = val.toDouble();
        } else if (val != null) saldo = double.tryParse(val.toString()) ?? 0.0;
      }
    } catch (e) {
      print('Erro ao consultar estoque: $e');
    }
    return saldo;
  }

  Future<void> _incrementarQuantidade(ProdutoResultStruct p) async {
    if (_isEdicaoBloqueada()) return;
    final existing = _findCartItem(p.codigo);
    final saldo = await _getSaldoEstoque(p.codigo);
    if (!mounted) return;

    if (saldo <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estoque indisponível para este produto (${p.descricao})'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final currentQty = existing != null ? existing.quantidade : 0.0;
    if (currentQty >= saldo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estoque máximo atingido! Saldo disponível: ${saldo.toInt()}'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // PRD B6: ValidePCOValues antes de incrementar
    {
      final res = await validarProduto(p.preco, saldo,
          pcomin: p.pcomin, pcomax: p.pcomax, commax: p.commax, freadpco: p.freadpco);
      if (!res.valido) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.mensagem), backgroundColor: Colors.orangeAccent),
        );
        return;
      }
    }

    safeSetState(() {
      if (existing != null) {
        existing.quantidade = existing.quantidade + 1.0;
        existing.totalItem = existing.quantidade * existing.precoUnitario;
        // PRD B4: recalcula unidade comercial = qtd * mulver
        existing.unidadeComercial = existing.quantidade * (existing.mulver != 0 ? existing.mulver : 1.0);
      } else {
        final mul = p.mulver != 0 ? p.mulver : 1.0;
        _model.carrinhoItens.add(ItemPedidoStruct(
          codigoProduto: p.codigo,
          descricao: p.descricao,
          unidade: p.unidade,
          precoUnitario: p.preco,
          quantidade: 1.0,
          totalItem: p.preco,
          mulver: mul,
          unidadeComercial: 1.0 * mul,
          embalagem: p.embalagem.isNotEmpty ? p.embalagem : p.unidade,
          marca: p.marca,
          referencia: p.referenciaFormatada,
          codbar: p.codbar,
        ));
      }
      _model.recalcularTotais();
    });
    unawaited(_autoSalvarCarrinho());
  }

  void _decrementarQuantidade(ProdutoResultStruct p) {
    if (_isEdicaoBloqueada()) return;
    final existing = _findCartItem(p.codigo);
    if (existing == null) return;

    safeSetState(() {
      if (existing.quantidade > 1.0) {
        existing.quantidade = existing.quantidade - 1.0;
        existing.totalItem = existing.quantidade * existing.precoUnitario;
        existing.unidadeComercial = existing.quantidade * (existing.mulver != 0 ? existing.mulver : 1.0);
      } else {
        _model.carrinhoItens.remove(existing);
      }
      _model.recalcularTotais();
    });
    unawaited(_autoSalvarCarrinho());
  }

  void _removerItem(ProdutoResultStruct p) {
    if (_isEdicaoBloqueada()) return;
    final existing = _findCartItem(p.codigo);
    if (existing != null) {
      safeSetState(() {
        _model.carrinhoItens.remove(existing);
        _model.recalcularTotais();
      });
      unawaited(_autoSalvarCarrinho());
    }
  }

  String _formatCurrency(double val) {
    return val.toMoeda();
  }

  /// Permite editar a quantidade clicando no número de itens, com stepper e teclado numérico,
  /// idêntico ao modal de adicionar produto ao carrinho.
  Future<void> _abrirModalEditarQuantidade(ItemPedidoStruct item) async {
    if (_isEdicaoBloqueada()) return;

    final double saldo = await _getSaldoEstoque(item.codigoProduto);
    final bool validaEstoque = (AppState().ven_chkest == 1);
    final bool isBoni = item.isBonificacao;
    int quantidade = (isBoni ? item.quantidadeBonificada : item.quantidade).toInt();
    if (quantidade <= 0) quantidade = 1;
    final qtdController = TextEditingController(text: '$quantidade');

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: true,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(builderCtx).viewInsets.bottom + 16.0,
                        left: 16.0,
                        right: 16.0,
                        top: 12.0,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 48.0,
                              height: 5.0,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E3E7),
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    color: AppTheme.of(builderCtx).primary,
                                    size: 24.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    isBoni ? 'Editar Qtd. Bonificada' : 'Editar Quantidade',
                                    style: const TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF14181B),
                                    ),
                                  ),
                                ],
                              ),
                              AppIconButton(
                                borderColor: Colors.transparent,
                                borderRadius: 20.0,
                                borderWidth: 1.0,
                                buttonSize: 38.0,
                                fillColor: const Color(0xFFF1F4F8),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFF57636C),
                                  size: 20.0,
                                ),
                                onPressed: () => Navigator.of(modalContext).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8.0),
                          const Divider(height: 1.0, thickness: 1.0, color: Color(0xFFE0E3E7)),
                          const SizedBox(height: 14.0),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(color: const Color(0xFFE0E3E7)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cód. ${item.codigoProduto}',
                                  style: TextStyle(
                                    color: AppTheme.of(builderCtx).primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.0,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  item.descricao,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.0,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Preço: ${item.precoUnitario.toMoeda()}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                                    ),
                                    if (item.unidade.isNotEmpty)
                                      Text(
                                        'Un: ${item.unidade}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                                      ),
                                  ],
                                ),
                                if (!isBoni) ...[
                                  const SizedBox(height: 8.0),
                                  Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 16.0),
                                      const SizedBox(width: 4.0),
                                      const Text('Estoque disponível: ', style: TextStyle(color: Colors.grey, fontSize: 12.0)),
                                      Text(
                                        validaEstoque
                                            ? formatQuantity(saldo, unidade: item.unidade)
                                            : 'Ilimitado',
                                        style: TextStyle(
                                          color: (!validaEstoque || saldo > 0)
                                              ? AppTheme.of(builderCtx).primary
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAED5E6),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.remove, color: Colors.white),
                                  onPressed: quantidade > 1
                                      ? () => setModalState(() {
                                            quantidade--;
                                            qtdController.text = '$quantidade';
                                          })
                                      : null,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: SizedBox(
                                  width: 80.0,
                                  child: TextFormField(
                                    controller: qtdController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18.0,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: BorderSide(color: AppTheme.of(builderCtx).primary),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: BorderSide(color: AppTheme.of(builderCtx).primary),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8.0),
                                        borderSide: BorderSide(color: AppTheme.of(builderCtx).primary, width: 2.0),
                                      ),
                                    ),
                                    onTap: () {
                                      qtdController.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: qtdController.text.length,
                                      );
                                    },
                                    onChanged: (val) {
                                      int parsed = int.tryParse(val) ?? 0;
                                      if (validaEstoque && !isBoni && parsed > saldo) {
                                        parsed = saldo.toInt();
                                        qtdController.text = parsed.toString();
                                        qtdController.selection = TextSelection.collapsed(offset: qtdController.text.length);
                                      }
                                      setModalState(() {
                                        quantidade = parsed;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0288D1),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  onPressed: (!validaEstoque || isBoni || quantidade < saldo)
                                      ? () => setModalState(() {
                                            quantidade++;
                                            qtdController.text = '$quantidade';
                                          })
                                      : null,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total do Item', style: TextStyle(color: Colors.grey, fontSize: 16.0)),
                              Text(
                                isBoni ? 'R\$ 0,00' : (item.precoUnitario * quantidade).toMoeda(),
                                style: TextStyle(
                                  color: AppTheme.of(builderCtx).primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20.0),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(modalContext).pop(),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                    side: const BorderSide(color: Color(0xFFE0E3E7)),
                                  ),
                                  child: const Text('Cancelar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (quantidade <= 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('A quantidade deve ser maior que zero.'),
                                          backgroundColor: Colors.orangeAccent,
                                        ),
                                      );
                                      return;
                                    }
                                    if (validaEstoque && !isBoni && quantidade > saldo) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Quantidade solicitada ($quantidade) excede o estoque disponível (${saldo.toInt()}).'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                      return;
                                    }
                                    safeSetState(() {
                                      if (isBoni) {
                                        item.quantidadeBonificada = quantidade.toDouble();
                                      } else {
                                        item.quantidade = quantidade.toDouble();
                                        item.totalItem = item.quantidade * item.precoUnitario;
                                        item.unidadeComercial = item.quantidade * (item.mulver != 0 ? item.mulver : 1.0);
                                      }
                                      _model.recalcularTotais();
                                    });
                                    unawaited(_autoSalvarCarrinho());
                                    Navigator.of(modalContext).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.of(builderCtx).primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                                  ),
                                  child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    qtdController.dispose();
  }

  /// PRD Seção 1 — Edição interativa do preço unitário com validação de faixas (pcomin/pcomax)
  Future<void> _exibirDialogEdicaoPreco(ItemPedidoStruct item) async {
    if (_isEdicaoBloqueada()) return;
    if (item.isBonificacao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é permitido alterar o preço de um item bonificado.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final int tabId = int.tryParse(_currentPlanoCodigo ?? widget.planoCodigo ?? '0') ?? 0;
    final faixa = await ValidePcoService.obterFaixasPreco(
      item.codigoProduto,
      codTabela: tabId,
    );

    if (!faixa.freadpco) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Representante sem permissão para alteração de preços!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;

    final precoController = TextEditingController(
      text: item.precoUnitario > 0 ? item.precoUnitario.toStringAsFixed(2) : '',
    );
    String? erroValidacao;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              title: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: AppTheme.of(context).primary),
                  const SizedBox(width: 8),
                  const Text('Editar Preço Unitário', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.codigoProduto} - ${item.descricao}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Preço Mínimo:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                faixa.pcomin > 0 ? _formatCurrency(faixa.pcomin) : 'Livre',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Preço Máximo:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                faixa.pcomax < 999999 ? _formatCurrency(faixa.pcomax) : 'Livre',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: precoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Novo Preço Unitário (R\$)',
                        prefixText: 'R\$ ',
                        errorText: erroValidacao,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        if (erroValidacao != null) {
                          setDialogState(() => erroValidacao = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.of(context).primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final cleanText = precoController.text.trim().replaceAll(',', '.');
                    final novoPreco = double.tryParse(cleanText);

                    if (novoPreco == null || novoPreco <= 0) {
                      setDialogState(() {
                        erroValidacao = 'Informe um preço válido maior que zero.';
                      });
                      return;
                    }

                    final res = ValidePcoService.validePCOValues(
                      pcomin: faixa.pcomin,
                      pcomax: faixa.pcomax,
                      commax: faixa.commax,
                      digpco: novoPreco,
                      destot: 0.0,
                      freadpco: faixa.freadpco,
                      isEdicaoManual: true,
                    );

                    if (!res.valido) {
                      setDialogState(() {
                        erroValidacao = res.mensagem;
                      });
                      return;
                    }

                    // Preço válido! Atualiza item e totais
                    safeSetState(() {
                      item.precoUnitario = novoPreco;
                      item.totalItem = item.quantidade * novoPreco;
                      _model.recalcularTotais();
                    });
                    unawaited(_autoSalvarCarrinho());
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Preço atualizado para ${_formatCurrency(novoPreco)}!'),
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                    );
                  },
                  child: const Text('Salvar Preço', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _obterAgentePadraoCliente() async {
    try {
      final cli = await carregarClienteOffline(widget.clienteCodigo ?? 0);
      final cod = cli?.cli00Codage;
      if (cod != null && cod != 0) return cod.toString();
    } catch (_) {}
    return null;
  }

  Future<void> _fluxoConcluirVenda() async {
    if (_model.carrinhoItens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carrinho vazio! Adicione itens antes de concluir.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // ── Validação de Valor Mínimo do Plano (pla00_vlrmin - Seção 2.3) ─────────────
    final int plaId = int.tryParse(_currentPlanoCodigo ?? widget.planoCodigo ?? '0') ?? 0;
    if (plaId > 0) {
      try {
        final db = await LocalSalesDatabaseService.getDatabase();
        final colsPla = await db.rawQuery('PRAGMA table_info(cadpla00)');
        final plaColNames = colsPla.map((r) => r['name'].toString().toLowerCase()).toSet();
        if (plaColNames.contains('pla00_vlrmin')) {
          final rPla = await db.rawQuery('SELECT pla00_vlrmin FROM cadpla00 WHERE pla00_codigo = ? LIMIT 1', [plaId]);
          if (rPla.isNotEmpty && rPla.first['pla00_vlrmin'] != null) {
            final vMin = (rPla.first['pla00_vlrmin'] is num)
                ? (rPla.first['pla00_vlrmin'] as num).toDouble()
                : (double.tryParse(rPla.first['pla00_vlrmin'].toString()) ?? 0.0);
            if (vMin > 0 && _model.valorTotal < vMin) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Valor total do pedido inferior ao valor mínimo exigido pelo plano de pagamento (Mínimo: ${_formatCurrency(vMin)})!'),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 4),
                ),
              );
              return;
            }
          }
        }
      } catch (e) {
        print('Erro ao checar valor minimo do plano: $e');
      }
    }

    // ── Passo A: Determina pedidoId definitivo e salva carrinho no SQLite ────────
    // Garante que pckvendig000 e pckvendig010 contenham o cabeçalho e os itens
    // com o pedidoId exato ANTES de abrir o modal do cobrador.
    final int pedidoIdDefinitivo = (widget.pedidoId != null && widget.pedidoId != 0)
        ? widget.pedidoId!
        : (AppState().pedido_numero != 0 ? AppState().pedido_numero : await obterProximoNumeroPedido());

    print('[_fluxoConcluirVenda] PRE-SAVE carrinho pedido #$pedidoIdDefinitivo itens=${_model.carrinhoItens.length}');
    final preSaveOk = await salvarCarrinhoPedido(
      pedidoId: pedidoIdDefinitivo,
      clienteCodigo: _clienteCodigo ?? widget.clienteCodigo ?? 0,
      linhaCodigo: _currentLinhaCodigo,
      planoCodigo: _currentPlanoCodigo,
      carrinhoItens: _model.carrinhoItens,
      bonfrcven: _chkBonFrcVen ? 1 : 0,
    );
    if (!preSaveOk) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falha ao salvar o carrinho. Tente novamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // ── Passo B: Abre modal do cobrador aguardando seleção com filtragem estrita ──
    final agentePre = await _obterAgentePadraoCliente();
    if (!mounted) return;
    final String? agenteSelecionado = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModalAgenteCobradorWidget(
        agentePreSelecionado: agentePre,
        clienteCodigo: _clienteCodigo ?? widget.clienteCodigo,
        planoCodigo: int.tryParse(_currentPlanoCodigo ?? widget.planoCodigo ?? ''),
      ),
    );
    if (!mounted) return;
    // Se o usuário fechou o modal no 'X' ou cancelou: aborta o fluxo sem gravar
    if (agenteSelecionado == null) {
      return;
    }

    // ── Passo B2 (SPEC-042): Abre campo Observação do Pedido pós-Agente Cobrador ──
    final String? obsDigitada = await ModalObservacaoPedidoWidget.show(context);
    if (!mounted) return;
    if (obsDigitada == null) {
      return;
    }

    // ── Passo C: Conclui venda passando o mesmo pedidoId que foi pré-salvo ───────
    await _finalizarSelecao(
      pedidoIdDefinitivo,
      codAgenteSelecionado: agenteSelecionado.isEmpty ? null : agenteSelecionado,
      observacao: obsDigitada,
    );
  }

  Future<void> _finalizarSelecao(
    int pedidoIdDefinitivo, {
    String? codAgenteSelecionado,
    String? observacao,
  }) async {
    if (_model.carrinhoItens.isEmpty) return;

    safeSetState(() {
      _model.isLoading = true;
    });

    final int effectivePedidoId = pedidoIdDefinitivo;
    final int effectiveClienteCodigo = _clienteCodigo ?? widget.clienteCodigo ?? 0;
    final int? codAgtInt = int.tryParse(codAgenteSelecionado ?? '');

    try {
      final success = await concluirVendaProcess(
        pedidoId: effectivePedidoId,
        clienteCodigo: effectiveClienteCodigo,
        linhaCodigo: _currentLinhaCodigo,
        planoCodigo: _currentPlanoCodigo,
        carrinhoItens: _model.carrinhoItens,
        codAgenteCobrador: codAgtInt,
        bonfrcven: _chkBonFrcVen ? 1 : 0,
        observacao: observacao ?? '',
      );

      safeSetState(() {
        _model.isLoading = false;
      });

      if (!mounted) return;

      if (success) {
        // PRD C2 doPEDPost: trava grid localmente após DIGITADO
        if (mounted) setState(() => _pedidoDigitado = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Venda realizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pushNamed(
          PedidoResumoWidget.routeName,
          queryParameters: {
            'pedidoId': effectivePedidoId.toString(),
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao concluir a venda no SQLite local. Tente novamente.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e, stack) {
      print('ERRO GRAVACAO PEDIDO: $e \n $stack');
      safeSetState(() {
        _model.isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao concluir a venda: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _abrirModalBusca() async {
    if (_isEdicaoBloqueada()) return;
    final filtro = _model.searchController.text.trim();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BuscaProdutoPageWidget(
          isSelectionMode: true,
          filtroInicial: filtro.isNotEmpty ? filtro : null,
        ),
      ),
    );

    if (result != null && result is ItemPedidoStruct) {
      final saldo = await _getSaldoEstoque(result.codigoProduto);
      if (!mounted) return;

      final existing = _findCartItem(result.codigoProduto);
      final currentQty = existing != null ? existing.quantidade : 0.0;
      final newQty = currentQty + result.quantidade;

      if (saldo <= 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estoque indisponível para este produto (${result.descricao})'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      double qtdAdicionar = result.quantidade;

      if (newQty > saldo) {
        final allowedQty = saldo - currentQty;
        if (allowedQty <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Estoque máximo atingido! Saldo disponível: ${saldo.toInt()}, no carrinho: ${currentQty.toInt()}'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estoque insuficiente para a quantidade total! Adicionando apenas ${allowedQty.toInt()} un.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        qtdAdicionar = allowedQty;
      }

      safeSetState(() {
        if (existing != null) {
          existing.quantidade += qtdAdicionar;
          existing.totalItem = existing.quantidade * existing.precoUnitario;
          existing.unidadeComercial = existing.quantidade * (existing.mulver != 0 ? existing.mulver : 1.0);
        } else {
          final mul = (result.mulver != 0) ? result.mulver : 1.0;
          result.quantidade = qtdAdicionar;
          result.totalItem = result.quantidade * result.precoUnitario;
          result.mulver = mul;
          result.unidadeComercial = result.quantidade * mul;
          _model.carrinhoItens.add(result);
        }
        _model.recalcularTotais();
      });
      unawaited(_autoSalvarCarrinho());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.descricao} adicionado ao pedido!'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF1F4F8),
        appBar: AppBar(
          backgroundColor: AppTheme.of(context).primary,
          automaticallyImplyLeading: true,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digitação do Pedido',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(_clienteNome != null && _clienteNome!.isNotEmpty ? _clienteNome! : widget.clienteNome ?? 'Sem Cliente')} - Cód. ${_clienteCodigo ?? widget.clienteCodigo ?? ''}',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12.0,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () {
                safeSetState(() {
                  _model.carrinhoItens.clear();
                  _model.recalcularTotais();
                });
              },
            ),
          ],
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Customer Details Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: AppTheme.of(context).primary, size: 20),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            (_clienteNome != null && _clienteNome!.isNotEmpty) ? _clienteNome! : (widget.clienteNome ?? ''),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        const Icon(Icons.description_outlined, color: Colors.grey, size: 16),
                        const SizedBox(width: 8.0),
                        Text((_clienteCnpj != null && _clienteCnpj!.isNotEmpty) ? _clienteCnpj! : (widget.clienteCnpj ?? ''), style: const TextStyle(color: Colors.grey, fontSize: 13.0)),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            (_clienteCidade != null && _clienteCidade!.isNotEmpty) ? _clienteCidade! : (widget.clienteCidade ?? ''),
                            style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if ((_clienteEndereco != null && _clienteEndereco!.isNotEmpty) || (widget.clienteEndereco != null && widget.clienteEndereco!.isNotEmpty)) ...[
                      const SizedBox(height: 4.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.home_outlined, color: Colors.grey, size: 16),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              (_clienteEndereco != null && _clienteEndereco!.isNotEmpty) ? _clienteEndereco! : (widget.clienteEndereco ?? ''),
                              style: const TextStyle(color: Colors.grey, fontSize: 13.0),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 16.0, color: Color(0xFFE0E3E7)),
                    Row(
                      children: [
                        Text('Limite: ', style: TextStyle(color: AppTheme.of(context).primary, fontWeight: FontWeight.bold, fontSize: 14.0)),
                        Text('R\$ ${(_clienteLimite != null && _clienteLimite!.isNotEmpty) ? _clienteLimite! : (widget.clienteLimite ?? "0,00")}', style: TextStyle(color: AppTheme.of(context).primary, fontWeight: FontWeight.bold, fontSize: 14.0)),
                      ],
                    ),
                    const Divider(height: 16.0, color: Color(0xFFE0E3E7)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.credit_card, color: AppTheme.of(context).primary, size: 16),
                              const SizedBox(width: 4.0),
                              Flexible(
                                child: Text('Plano: ${_currentPlanoDescricao ?? ''}', style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.layers, color: AppTheme.of(context).primary, size: 16),
                              const SizedBox(width: 4.0),
                              Flexible(
                                child: Text('Linha: ${_currentLinhaDescricao ?? ''}', style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // PRD C3 — chk_bonfrcven só se ven00_gerbonfor==1
                    if (AppState().ven_gerbonfor == 1) ...[
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard, size: 16, color: Colors.orange),
                          const SizedBox(width: 4.0),
                          const Text('Bonificação Força Venda', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Switch(
                            value: _chkBonFrcVen,
                            onChanged: _pedidoDigitado ? null : (v) => setState(() => _chkBonFrcVen = v),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Teal Summary Bar
              Container(
                color: AppTheme.of(context).primary,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Itens', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
                          const SizedBox(height: 2.0),
                          Text('${_model.carrinhoItens.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.0)),
                        ],
                      ),
                    ),
                    Container(height: 30.0, width: 1.0, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Qtd Total', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
                          const SizedBox(height: 2.0),
                          Text('${_model.totalItens}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.0)),
                        ],
                      ),
                    ),
                    Container(height: 30.0, width: 1.0, color: Colors.white24),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Subtotal', style: TextStyle(color: Colors.white70, fontSize: 12.0)),
                          const SizedBox(height: 2.0),
                          Text(_formatCurrency(_model.valorTotal), style: const TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 18.0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Main List Area (Cart)
              Expanded(
                child: _model.carrinhoItens.isEmpty
                    ? const Center(
                        child: Text(
                          'O carrinho está vazio.\nBusque um produto abaixo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16.0),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12.0),
                        itemCount: _model.carrinhoItens.length,
                        itemBuilder: (context, index) {
                          final item = _model.carrinhoItens[index];
                          final p = ProdutoResultStruct(
                            codigo: item.codigoProduto,
                            descricao: item.descricao,
                            unidade: item.unidade,
                            preco: item.precoUnitario,
                            marca: item.marca,
                            referencia1: item.referencia,
                            codbar: item.codbar,
                            embalagem: item.embalagem,
                          );

                          return ItemPedidoCardWidget(
                            item: item,
                            pedidoDigitado: _pedidoDigitado,
                            onRemover: () => _removerItem(p),
                            onIncrementar: () => _incrementarQuantidade(p),
                            onDecrementar: () => _decrementarQuantidade(p),
                            onEditarPreco: () => _exibirDialogEdicaoPreco(item),
                            onEditarQuantidade: () => _abrirModalEditarQuantidade(item),
                          );
                        },
                      ),
              ),
              // Bottom Fixed Actions
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 4.0, offset: Offset(0, -2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _model.searchController,
                            decoration: InputDecoration(
                              hintText: 'Código ou nome do produto...',
                              hintStyle: const TextStyle(fontSize: 13.0, color: Colors.grey),
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFFE0E3E7))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: const BorderSide(color: Color(0xFFE0E3E7))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: AppTheme.of(context).primary)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0.0),
                            ),
                            onSubmitted: (val) => _abrirModalBusca(),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        SizedBox(
                          height: 48.0,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.of(context).primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                            onPressed: _abrirModalBusca,
                            child: const Text('Buscar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    SizedBox(
                      width: double.infinity,
                      height: 48.0,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.of(context).primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                        onPressed: _showAcoesPedidoModal,
                        child: Text('... Ações do Pedido', style: TextStyle(color: AppTheme.of(context).primary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAcoesPedidoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600.0),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.of(context).primaryBackground,
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10.0,
                      color: Color(0x33000000),
                      offset: Offset(0.0, -2.0),
                    )
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                          child: Container(
                            width: 40.0,
                            height: 4.0,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2.0),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    color: AppTheme.of(context).primary,
                                    size: 24.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Ações do Pedido',
                                    style: AppTheme.of(context).titleLarge.override(
                                          font: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          color: AppTheme.of(context).primaryText,
                                          fontSize: 20.0,
                                        ),
                                  ),
                                ],
                              ),
                              AppIconButton(
                                borderColor: const Color(0xFFE0E3E7),
                                borderRadius: 12.0,
                                borderWidth: 1.0,
                                buttonSize: 38.0,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.of(context).primaryText,
                                  size: 18.0,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1.0, thickness: 1.0),
                        const SizedBox(height: 12.0),
              _buildAcaoCard(
                icon: Icons.check_circle_outlined,
                label: 'Concluir Venda',
                bgColor: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF2E7D32),
                onTap: () {
                  Navigator.pop(context);
                  _fluxoConcluirVenda();
                },
              ),
              const SizedBox(height: 12.0),
              _buildAcaoCard(
                icon: Icons.card_giftcard_outlined,
                label: 'Incluir bonificação',
                bgColor: const Color(0xFFFFF3E0),
                iconColor: const Color(0xFFE65100),
                onTap: () async {
                  Navigator.pop(context);
                  final List<ItemPedidoStruct>? novosItens = await showModalBottomSheet<List<ItemPedidoStruct>>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return BottomSheetSelecaoBonificacaoWidget(
                        pedidoId: widget.pedidoId ?? 0,
                        linhaCodigo: widget.linhaCodigo,
                        tabelaCodigo: '0',
                      );
                    },
                  );

                  if (novosItens != null && novosItens.isNotEmpty) {
                    if (!context.mounted) return;
                    final confirma = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirmar inclusão'),
                        content: const Text('Deseja incluir os produtos na digitação?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
                        ],
                      ),
                    );
                    if (confirma != true) return;
                    setState(() {
                      _model.carrinhoItens.addAll(novosItens);
                    });
                    
                    // Salvar o carrinho atualizado no SQLite
                    await salvarCarrinhoPedido(
                      pedidoId: widget.pedidoId ?? 0,
                      clienteCodigo: widget.clienteCodigo ?? 0,
                      linhaCodigo: widget.linhaCodigo,
                      planoCodigo: widget.planoCodigo,
carrinhoItens: _model.carrinhoItens,
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bonificações adicionadas com sucesso!'),
                        backgroundColor: Color(0xFF5CB85C),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12.0),
              _buildAcaoCard(
                icon: Icons.widgets_outlined,
                label: 'Incluir combo',
                bgColor: const Color(0xFFF3E5F5),
                iconColor: const Color(0xFF6A1B9A),
                onTap: () async {
                  Navigator.pop(context);
                  final List<ItemPedidoStruct>? novosItens = await showModalBottomSheet<List<ItemPedidoStruct>>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return BottomSheetCombosWidget(
                        pedidoId: widget.pedidoId ?? 0,
                        codFilial: 1, // Poderíamos usar functions.resolverCodFilial(AppState().empresa_codigo)
                        codTabela: 0,
                        codLinha: widget.linhaCodigo,
                      );
                    },
                  );

                  if (novosItens != null && novosItens.isNotEmpty) {
                    if (!context.mounted) return;
                    final confirma = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirmar inclusão'),
                        content: const Text('Deseja incluir os produtos na digitação?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim')),
                        ],
                      ),
                    );
                    if (confirma != true) return;
                    setState(() {
                      _model.carrinhoItens.addAll(novosItens);
                    });
                    
                    await salvarCarrinhoPedido(
                      pedidoId: widget.pedidoId ?? 0,
                      clienteCodigo: widget.clienteCodigo ?? 0,
                      linhaCodigo: widget.linhaCodigo,
                      planoCodigo: widget.planoCodigo,
carrinhoItens: _model.carrinhoItens,
                    );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Combos adicionados com sucesso!'),
                        backgroundColor: Color(0xFF5CB85C),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12.0),
              _buildAcaoCard(
                icon: Icons.edit_outlined,
                label: 'Modificar Plano',
                bgColor: const Color(0xFFE1F5FE),
                iconColor: const Color(0xFF0277BD),
                onTap: () {
                  Navigator.pop(context);
                  _showPlanoSelectorInItensLista();
                },
              ),
              const SizedBox(height: 12.0),
              _buildAcaoCard(
                icon: Icons.delete_outline_rounded,
                label: 'Cancelar digitação de venda',
                bgColor: const Color(0xFFFFEBEE),
                iconColor: const Color(0xFFC62828),
                onTap: () {
                  Navigator.pop(context);
                  _cancelarVenda();
                },
              ),
              const SizedBox(height: 24.0),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Fechar',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                    color: AppTheme.of(context).primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
      },
    );
  }

  Widget _buildAcaoCard({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.all(8.0),
              child: Icon(icon, color: iconColor, size: 24.0),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.0,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelarVenda() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar Digitação'),
          content: const Text('Deseja realmente cancelar este pedido? Todos os itens digitados serão perdidos.'),
          actions: [
            TextButton(
              child: const Text('Voltar'),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Sim, Cancelar'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    safeSetState(() {
      _model.isLoading = true;
    });

    try {
      // Usa o singleton ativo — sem abrir conexão descartável
      final db = await LocalSalesDatabaseService.getDatabase();
      // PRD C2 doPEDAbort: rollback sttdig e DELETE WHERE numped sempre (nunca sem WHERE)
      try {
        final cols = await db.rawQuery('PRAGMA table_info(pckvendig000)');
        final cn = cols.map((r) => r['name'].toString().toLowerCase()).toSet();
        if (cn.contains('ped00_sttdig')) {
          await db.rawUpdate('UPDATE pckvendig000 SET ped00_sttdig = 0 WHERE ped00_numped = ?', [widget.pedidoId ?? 0]);
        }
      } catch (_) {}
      await db.rawDelete('DELETE FROM pckvendig010 WHERE ped10_numped = ?', [widget.pedidoId ?? 0]);
      await db.rawDelete('DELETE FROM pckvendig000 WHERE ped00_numped = ?', [widget.pedidoId ?? 0]);
      // Não fechar 'db' — é conexão singleton ativa da sessão do app.
    } catch (e) {
      print('Erro ao limpar tabelas temporarias: $e');
    }

    safeSetState(() {
      _model.isLoading = false;
      _model.carrinhoItens.clear();
      _model.recalcularTotais();
    });

    if (!mounted) return;
    context.go('/homePage');
  }

  List<ListaPadraoStruct> _planos = [];

  Future<void> _loadPlanos() async {
    try {
      final result = await carregarPlanosDisponiveisCliente(
        clienteCodigo: widget.clienteCodigo,
      );
      _planos = result;
    } catch (e) {
      print('Erro ao carregar planos: $e');
    }
  }

  Future<void> _showPlanoSelectorInItensLista() async {
    safeSetState(() {
      _model.isLoading = true;
    });
    await _loadPlanos();
    safeSetState(() {
      _model.isLoading = false;
    });
    if (!mounted) return;

    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtered = _planos.where((p) {
              final term = searchQuery.toLowerCase();
              final desc = p.descricao.toLowerCase();
              final cod = p.codigo.toLowerCase();
              return desc.contains(term) || cod.contains(term);
            }).toList();

            return Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600.0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: BoxDecoration(
                      color: AppTheme.of(context).primaryBackground,
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 10.0,
                          color: Color(0x33000000),
                          offset: Offset(0.0, -2.0),
                        )
                      ],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20.0),
                        topRight: Radius.circular(20.0),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: true,
                      child: Column(
                        children: [
                          // Drag handle
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                            child: Container(
                              width: 40.0,
                              height: 4.0,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(2.0),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.credit_card_rounded,
                                        color: AppTheme.of(context).primary,
                                        size: 24.0,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Text(
                                          'Selecionar Novo Plano',
                                          style: AppTheme.of(context).titleLarge.override(
                                                font: GoogleFonts.outfit(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                color: AppTheme.of(context).primaryText,
                                                fontSize: 20.0,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppIconButton(
                                  borderColor: const Color(0xFFE0E3E7),
                                  borderRadius: 12.0,
                                  borderWidth: 1.0,
                                  buttonSize: 38.0,
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.of(context).primaryText,
                                    size: 18.0,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1.0, thickness: 1.0),
                  const SizedBox(height: 8.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Pesquise por descrição ou código...',
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.of(context).secondaryText),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppTheme.of(context).alternate),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppTheme.of(context).alternate),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: AppTheme.of(context).primary, width: 2.0),
                        ),
                        filled: true,
                        fillColor: AppTheme.of(context).primaryBackground,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onChanged: (val) {
                        setStateDialog(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum plano encontrado.',
                              style: AppTheme.of(context).bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              final isSelected = _currentPlanoCodigo == p.codigo;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8.0),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppTheme.of(context).primary.withValues(alpha: 0.08) : Colors.white,
                                  borderRadius: BorderRadius.circular(12.0),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.of(context).primary : const Color(0xFFE0E3E7),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Icon(Icons.credit_card_outlined, color: isSelected ? AppTheme.of(context).primary : AppTheme.of(context).secondaryText),
                                  title: Text(
                                    p.descricao,
                                    style: AppTheme.of(context).bodyLarge.override(
                                          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        ),
                                  ),
                                  subtitle: Text(
                                    p.vlrmin > 0
                                        ? 'Código: ${p.codigo} • Mínimo: ${_formatCurrency(p.vlrmin)}'
                                        : 'Código: ${p.codigo}',
                                    style: AppTheme.of(context).bodyMedium,
                                  ),
                                  trailing: isSelected ? Icon(Icons.check_circle_rounded, color: AppTheme.of(context).primary) : null,
                                  onTap: () {
                                    safeSetState(() {
                                      _currentPlanoCodigo = p.codigo;
                                      _currentPlanoDescricao = p.descricao;
                                    });
                                    _salvarPlanoAlterado(p.codigo);
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
          },
        );
      },
    );
  }

  Future<void> _salvarPlanoAlterado(String planoCodigo) async {
    try {
      // Usa o singleton ativo — sem abrir conexão descartável
      final db = await LocalSalesDatabaseService.getDatabase();
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info(pckvendig000)');
      final colNames = columns.map((r) => r['name']?.toString().toLowerCase()).toSet();
      String colName = 'ped00_codpla';
      if (colNames.contains('ped00_codpag')) {
        colName = 'ped00_codpag';
      }
      final int plaVal = int.tryParse(planoCodigo) ?? 0;
      await db.rawUpdate(
        'UPDATE pckvendig000 SET $colName = ? WHERE ped00_numped = ?',
        [plaVal, widget.pedidoId ?? 0]
      );
      // Não fechar 'db' — é conexão singleton ativa da sessão do app.
      print('Plano atualizado com sucesso no cabeçalho SQLite do pedido.');
    } catch (e) {
      print('Erro ao persistir plano alterado no SQLite: $e');
    }
  }
}

