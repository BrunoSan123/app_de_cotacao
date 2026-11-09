import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset_price_point.dart';
import '../models/asset_quote.dart';
import '../state/trade_sim_controller.dart';

class AssetDetailsScreen extends StatefulWidget {
  const AssetDetailsScreen({required this.quote, super.key});

  final AssetQuote quote;

  @override
  State<AssetDetailsScreen> createState() => _AssetDetailsScreenState();
}

class _AssetDetailsScreenState extends State<AssetDetailsScreen> {
  static const _ranges = <String, String>{
    '1 mês': '1mo',
    '3 meses': '3mo',
    '6 meses': '6mo',
    '1 ano': '1y',
  };

  String _range = '1mo';
  List<AssetPricePoint> _history = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final history = await context
          .read<TradeSimController>()
          .fetchPriceHistory(widget.quote.symbol, range: _range);
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _history = const [];
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final positive = quote.changePercent >= 0;
    final changeColor = positive
        ? const Color(0xFF087F5B)
        : const Color(0xFFBF5D42);

    return Scaffold(
      appBar: AppBar(
        title: Text(quote.symbol),
        actions: [
          IconButton(
            tooltip: 'Atualizar histórico',
            onPressed: _isLoading ? null : _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  quote.name ?? quote.symbol,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF63736C),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      formatAssetCurrency(quote.price),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${positive ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const Text('última variação informada pela Brapi'),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Histórico de preços',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            DropdownButton<String>(
                              value: _range,
                              onChanged: _isLoading
                                  ? null
                                  : (range) {
                                      if (range == null) return;
                                      setState(() => _range = range);
                                      _loadHistory();
                                    },
                              items: _ranges.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.value,
                                      child: Text(entry.key),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 260,
                          child: _historyContent(),
                        ),
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _LegendDot(color: changeColor),
                              const SizedBox(width: 8),
                              Text(
                                'Fechamento ajustado por pregão · ${_history.length} registros',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Variações por pregão',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _ranges.entries
                          .firstWhere((entry) => entry.value == _range)
                          .key,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_isLoading && _history.isEmpty)
                  _HistoryError(
                    message: _error ?? 'A Brapi não retornou o histórico.',
                    onRetry: _loadHistory,
                  )
                else if (_history.isNotEmpty)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const _HistoryHeader(),
                        const Divider(height: 1),
                        for (var index = _history.length - 1; index >= 0; index--)
                          _HistoryRow(
                            point: _history[index],
                            previous: index > 0 ? _history[index - 1] : null,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    context
                        .read<TradeSimController>()
                        .openTradingFor(quote.symbol);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.swap_horiz),
                  label: Text('Operar ${quote.symbol}'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dados históricos fornecidos pela Brapi. Desempenho passado não garante resultados futuros.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return _HistoryError(
        message: _error ?? 'A Brapi não retornou o histórico.',
        onRetry: _loadHistory,
      );
    }
    return _PriceChart(points: _history);
  }
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.points});

  final List<AssetPricePoint> points;

  @override
  Widget build(BuildContext context) {
    final prices = points.map((point) => point.price).toList();
    final minimum = prices.reduce(math.min);
    final maximum = prices.reduce(math.max);
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 68,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatAssetCurrency(maximum)),
                    Text(formatAssetCurrency((minimum + maximum) / 2)),
                    Text(formatAssetCurrency(minimum)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomPaint(
                  painter: _PriceChartPainter(
                    prices: prices,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatAssetDate(points.first.date)),
            Text(formatAssetDate(points.last.date)),
          ],
        ),
      ],
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  const _PriceChartPainter({required this.prices, required this.color});

  final List<double> prices;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty) return;
    final gridPaint = Paint()
      ..color = const Color(0xFFE9EFEC)
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final spread = maxPrice - minPrice;
    final padding = spread == 0 ? maxPrice.abs() * 0.02 + 0.01 : spread * 0.1;
    final lower = minPrice - padding;
    final range = (maxPrice + padding) - lower;
    final line = Path();
    for (var index = 0; index < prices.length; index++) {
      final x = prices.length == 1
          ? size.width / 2
          : size.width * index / (prices.length - 1);
      final y = size.height * (1 - (prices[index] - lower) / range);
      if (index == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.01)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter oldDelegate) {
    return oldDelegate.prices != prices || oldDelegate.color != color;
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Pregão', style: style)),
          Expanded(child: Text('Fechamento', style: style, textAlign: TextAlign.end)),
          Expanded(child: Text('Variação', style: style, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.point, required this.previous});

  final AssetPricePoint point;
  final AssetPricePoint? previous;

  @override
  Widget build(BuildContext context) {
    final change = previous == null || previous!.price == 0
        ? null
        : (point.price - previous!.price) / previous!.price * 100;
    final color = change == null
        ? Theme.of(context).colorScheme.onSurface
        : change >= 0
        ? const Color(0xFF087F5B)
        : const Color(0xFFBF5D42);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(formatAssetDate(point.date)),
              ),
              Expanded(
                child: Text(
                  formatAssetCurrency(point.price),
                  textAlign: TextAlign.end,
                ),
              ),
              Expanded(
                child: Text(
                  change == null
                      ? '—'
                      : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFF71837B)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

String formatAssetCurrency(double value) => 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

String formatAssetDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
