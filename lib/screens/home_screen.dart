import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'asset_details_screen.dart';
import '../models/asset_quote.dart';
import '../models/trade_order.dart';
import '../models/wallet_transaction.dart';
import '../state/trade_sim_controller.dart';

const _navigationItems = [
  (label: 'Visão geral', icon: Icons.grid_view_rounded),
  (label: 'Mercado', icon: Icons.show_chart_rounded),
  (label: 'Carteira', icon: Icons.account_balance_wallet_outlined),
  (label: 'Operar', icon: Icons.swap_horiz_rounded),
  (label: 'Ordens', icon: Icons.receipt_long_outlined),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final page = _selectedPage(controller.selectedTab);

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const _Brand(),
              actions: [
                IconButton(
                  tooltip: 'Atualizar cotações',
                  onPressed: controller.isRefreshingQuotes
                      ? null
                      : controller.refreshQuotes,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Sair',
                  onPressed: () => _runAction(context, controller.signOut()),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
      body: wide
          ? Row(
              children: [
                _Sidebar(selectedIndex: controller.selectedTab),
                Expanded(
                  child: Column(
                    children: [
                      _DesktopHeader(),
                      Expanded(child: page),
                    ],
                  ),
                ),
              ],
            )
          : page,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: controller.selectedTab,
              onDestinationSelected: controller.selectTab,
              destinations: _navigationItems
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _selectedPage(int selectedTab) {
    return switch (selectedTab) {
      0 => const OverviewPage(),
      1 => const MarketPage(),
      2 => const WalletPage(),
      3 => const TradingPage(),
      _ => const OrdersPage(),
    };
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE9EFEC))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 16, 28),
            child: _Brand(),
          ),
          for (var index = 0; index < _navigationItems.length; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  selected: selectedIndex == index,
                  selectedColor: const Color(0xFF087F5B),
                  selectedTileColor: const Color(0xFFEAF5EF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(_navigationItems[index].icon),
                  title: Text(_navigationItems[index].label),
                  onTap: () =>
                      context.read<TradeSimController>().selectTab(index),
                ),
              ),
            ),
          const Spacer(),
          const Divider(height: 1),
          Consumer<TradeSimController>(
            builder: (context, controller, _) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(
                controller.user?.fullName ?? 'Investidor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('Conta simulada'),
              trailing: IconButton(
                tooltip: 'Sair',
                onPressed: () => _runAction(context, controller.signOut()),
                icon: const Icon(Icons.logout),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EFEC))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _navigationItems[controller.selectedTab].label,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.circle, size: 10, color: Color(0xFF35A978)),
          const SizedBox(width: 8),
          Text(
            controller.isRefreshingQuotes
                ? 'Carregando mercado'
                : controller.quoteError == null
                ? 'Cotações da Brapi'
                : 'Mercado indisponível',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'Atualizar cotações',
            onPressed: controller.isRefreshingQuotes
                ? null
                : controller.refreshQuotes,
            icon: controller.isRefreshingQuotes
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            child: Text(
              (controller.user?.fullName ?? 'T').substring(0, 1).toUpperCase(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.candlestick_chart, color: Color(0xFF087F5B), size: 28),
        const SizedBox(width: 9),
        Text(
          'TradeSim',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF143D30),
          ),
        ),
      ],
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    return _PageScaffold(
      title:
          'Olá, ${controller.user?.fullName.split(' ').first ?? 'investidor'}',
      subtitle: 'Acompanhe sua carteira e o mercado em um só lugar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuoteStatus(),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 1000 ? 3 : 1;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    width: _cardWidth(constraints.maxWidth, columns),
                    label: 'Patrimônio total',
                    value: formatCurrency(controller.totalEquity),
                    icon: Icons.account_balance,
                    color: const Color(0xFF087F5B),
                  ),
                  _StatCard(
                    width: _cardWidth(constraints.maxWidth, columns),
                    label: 'Saldo disponível',
                    value: formatCurrency(controller.cashBalance),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF3B82C4),
                    action: 'Adicionar / retirar',
                    onTap: () => controller.selectTab(2),
                  ),
                  _StatCard(
                    width: _cardWidth(constraints.maxWidth, columns),
                    label: 'Em custódia',
                    value: formatCurrency(controller.investedValue),
                    icon: Icons.pie_chart_outline,
                    color: const Color(0xFF8A65C7),
                    action: '${controller.holdings.length} ativos',
                    onTap: () => controller.selectTab(2),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          _SectionHeading(
            title: 'Acompanhe o mercado',
            actionLabel: 'Ver todos',
            onAction: () => controller.selectTab(1),
          ),
          const SizedBox(height: 12),
          _QuoteList(quotes: controller.quotes.take(4).toList()),
          const SizedBox(height: 28),
          _SectionHeading(
            title: 'Posições day trade abertas',
            actionLabel: 'Ver ordens',
            onAction: () => controller.selectTab(4),
          ),
          const SizedBox(height: 12),
          if (controller.openDayTrades.isEmpty)
            const _EmptyState(
              icon: Icons.bolt_outlined,
              title: 'Nenhuma posição aberta',
              message:
                  'Quando abrir uma operação day trade, ela aparecerá aqui.',
            )
          else
            ...controller.openDayTrades.map(
              (order) => _DayTradeTile(order: order),
            ),
        ],
      ),
    );
  }
}

class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    return _PageScaffold(
      title: 'Mercado',
      subtitle: 'Cotações das principais ações da B3.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuoteStatus(),
          const SizedBox(height: 16),
          TextField(
            onChanged: controller.updateSearch,
            decoration: const InputDecoration(
              hintText: 'Buscar ativo, ex.: PETR4',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          if (controller.filteredQuotes.isEmpty &&
              controller.isRefreshingQuotes)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (controller.filteredQuotes.isEmpty)
            _EmptyState(
              icon: controller.quoteError == null
                  ? Icons.search_off
                  : Icons.cloud_off,
              title: controller.quoteError == null
                  ? 'Nenhum ativo encontrado'
                  : 'Não foi possível carregar o mercado',
              message:
                  controller.quoteError ??
                  'Tente buscar outro ticker ou nome de empresa.',
            )
          else
            _QuoteList(quotes: controller.filteredQuotes),
          if (controller.hasMoreQuotes)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: controller.isLoadingMoreQuotes
                    ? null
                    : controller.loadMoreQuotes,
                child: controller.isLoadingMoreQuotes
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Carregar mais ativos'),
              ),
            ),
        ],
      ),
    );
  }
}

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    return _PageScaffold(
      title: 'Minha carteira',
      subtitle: 'Gerencie o saldo e acompanhe seus ativos em custódia.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                width: 300,
                label: 'Saldo disponível',
                value: formatCurrency(controller.cashBalance),
                icon: Icons.payments_outlined,
                color: const Color(0xFF3B82C4),
              ),
              _StatCard(
                width: 300,
                label: 'Valor dos ativos',
                value: formatCurrency(controller.investedValue),
                icon: Icons.pie_chart_outline,
                color: const Color(0xFF8A65C7),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _showTransferDialog(context, WalletTransactionType.deposit),
                icon: const Icon(Icons.add),
                label: const Text('Simular depósito'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showTransferDialog(
                  context,
                  WalletTransactionType.withdrawal,
                ),
                icon: const Icon(Icons.south_west),
                label: const Text('Simular saque'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionHeading(title: 'Ativos em custódia'),
          const SizedBox(height: 12),
          if (controller.holdings.isEmpty)
            const _EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'Sua carteira ainda está vazia',
              message: 'Compre ativos na aba Operar para vê-los aqui.',
            )
          else
            ...controller.holdings.entries.map((entry) {
              final quote = controller.quoteFor(entry.key);
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.show_chart)),
                  title: Text(entry.key),
                  subtitle: Text(
                    quote == null
                        ? '${entry.value} ações · cotação não carregada'
                        : '${entry.value} ações · ${formatCurrency(quote.price)} cada',
                  ),
                  trailing: Text(
                    quote == null
                        ? '—'
                        : formatCurrency(entry.value * quote.price),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            }),
          const SizedBox(height: 28),
          const _SectionHeading(title: 'Movimentações'),
          const SizedBox(height: 12),
          if (controller.user!.wallet.transactions.isEmpty)
            const _EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhuma movimentação ainda',
              message: 'Depósitos e saques simulados ficarão registrados aqui.',
            )
          else
            ...controller.user!.wallet.transactions.map((transaction) {
              final deposit = transaction.type == WalletTransactionType.deposit;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: deposit
                        ? const Color(0xFFE5F5EC)
                        : const Color(0xFFFFEFEA),
                    child: Icon(
                      deposit ? Icons.south_west : Icons.north_east,
                      color: deposit
                          ? const Color(0xFF087F5B)
                          : const Color(0xFFBF5D42),
                    ),
                  ),
                  title: Text(deposit ? 'Depósito simulado' : 'Saque simulado'),
                  subtitle: Text(formatDate(transaction.createdAt)),
                  trailing: Text(
                    '${deposit ? '+' : '-'}${formatCurrency(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: deposit
                          ? const Color(0xFF087F5B)
                          : const Color(0xFFBF5D42),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class TradingPage extends StatefulWidget {
  const TradingPage({super.key});

  @override
  State<TradingPage> createState() => _TradingPageState();
}

class _TradingPageState extends State<TradingPage> {
  final _quantityController = TextEditingController(text: '10');
  final _priceController = TextEditingController();
  String? _symbol;
  TradeType _type = TradeType.swing;
  OrderSide _side = OrderSide.buy;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    final symbols = controller.quotes.map((quote) => quote.symbol).toList();
    if (_symbol != null && !symbols.contains(_symbol)) {
      _symbol = null;
    }
    if (symbols.isNotEmpty && _symbol == null) {
      final preferredSymbol = controller.selectedTradeSymbol;
      _symbol = symbols.contains(preferredSymbol)
          ? preferredSymbol
          : symbols.first;
      _priceController.text =
          controller.quoteFor(_symbol!)?.price.toStringAsFixed(2) ?? '';
    }
    final currentQuote = _symbol == null ? null : controller.quoteFor(_symbol!);
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final price = parseAmount(_priceController.text) ?? 0;

    return _PageScaffold(
      title: 'Nova operação',
      subtitle: 'Simulação de ordens. Nenhuma ordem real é enviada à bolsa.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuoteStatus(),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Configurar ordem',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 20),
                        SegmentedButton<TradeType>(
                          segments: const [
                            ButtonSegment(
                              value: TradeType.swing,
                              label: Text('Swing trade'),
                              icon: Icon(Icons.trending_up),
                            ),
                            ButtonSegment(
                              value: TradeType.day,
                              label: Text('Day trade'),
                              icon: Icon(Icons.bolt),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (selection) =>
                              setState(() => _type = selection.first),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _type == TradeType.swing
                              ? 'Compra ou venda simulada que altera sua custódia.'
                              : 'Posição comprada intradiária, encerrada pelo preço atual.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        if (symbols.isEmpty)
                          const _EmptyState(
                            icon: Icons.cloud_off,
                            title: 'Ativos da B3 indisponíveis',
                            message: 'A ordem só pode ser criada com um ativo e preço retornados pela Brapi.',
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: _symbol,
                            decoration: const InputDecoration(
                              labelText: 'Ativo',
                              prefixIcon: Icon(Icons.show_chart),
                            ),
                            items: symbols
                                .map(
                                  (symbol) => DropdownMenuItem(
                                    value: symbol,
                                    child: Text(symbol),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _symbol = value;
                                _priceController.text =
                                    controller
                                        .quoteFor(value)
                                        ?.price
                                        .toStringAsFixed(2) ??
                                    '';
                              });
                            },
                          ),
                        const SizedBox(height: 14),
                        if (_type == TradeType.swing)
                          SegmentedButton<OrderSide>(
                            segments: const [
                              ButtonSegment(
                                value: OrderSide.buy,
                                label: Text('Comprar'),
                              ),
                              ButtonSegment(
                                value: OrderSide.sell,
                                label: Text('Vender'),
                              ),
                            ],
                            selected: {_side},
                            onSelectionChanged: (selection) =>
                                setState(() => _side = selection.first),
                          ),
                        if (_type == TradeType.swing)
                          const SizedBox(height: 14),
                        TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantidade de ações',
                            helperText:
                                _side == OrderSide.sell &&
                                    _type == TradeType.swing
                                ? 'Em custódia: ${controller.holdings[_symbol] ?? 0}'
                                : null,
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Preço por ação (R\$)',
                            helperText: currentQuote == null
                                ? null
                                : 'Última cotação: ${formatCurrency(currentQuote.price)}',
                            prefixIcon: const Icon(Icons.currency_exchange),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F7F4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Expanded(child: Text('Valor estimado')),
                              Text(
                                formatCurrency(qty * price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed:
                              _symbol == null ||
                                  currentQuote == null ||
                                  qty < 1 ||
                                  price <= 0
                              ? null
                              : () => _placeOrder(controller, qty, price),
                          icon: const Icon(Icons.check),
                          label: Text(
                            _type == TradeType.day
                                ? 'Abrir posição'
                                : _side == OrderSide.buy
                                ? 'Confirmar compra simulada'
                                : 'Confirmar venda simulada',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (controller.openDayTrades.isNotEmpty) ...[
            const SizedBox(height: 28),
            const _SectionHeading(title: 'Posições abertas'),
            const SizedBox(height: 10),
            ...controller.openDayTrades.map(
              (order) => _DayTradeTile(order: order),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _placeOrder(
    TradeSimController controller,
    int quantity,
    double price,
  ) async {
    final symbol = _symbol!;
    if (_type == TradeType.day) {
      await _runAction(
        context,
        controller.openDayTrade(
          symbol: symbol,
          quantity: quantity,
          price: price,
        ),
        successMessage: 'Posição day trade aberta.',
      );
    } else {
      await _runAction(
        context,
        controller.placeSwingOrder(
          symbol: symbol,
          side: _side,
          quantity: quantity,
          price: price,
        ),
        successMessage: 'Ordem swing trade executada.',
      );
    }
  }
}

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    final open = controller.orders
        .where(
          (order) =>
              order.type == TradeType.day && order.status == OrderStatus.open,
        )
        .toList();
    final custody = controller.swingOrders;
    final closed = controller.orders
        .where((order) => order.status == OrderStatus.closed)
        .toList();

    return _PageScaffold(
      title: 'Ordens e operações',
      subtitle: 'Acompanhe posições abertas, custódia e operações encerradas.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(title: 'Day trade em aberto (${open.length})'),
          const SizedBox(height: 12),
          if (open.isEmpty)
            const _EmptyState(
              icon: Icons.bolt_outlined,
              title: 'Sem operações abertas',
              message: 'As posições day trade abertas aparecem aqui.',
            )
          else
            ...open.map((order) => _DayTradeTile(order: order)),
          const SizedBox(height: 28),
          _SectionHeading(title: 'Custódia swing trade (${custody.length})'),
          const SizedBox(height: 12),
          if (custody.isEmpty)
            const _EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'Sem ordens em custódia',
              message: 'Ordens swing trade executadas serão listadas aqui.',
            )
          else
            ...custody.map((order) => _OrderTile(order: order)),
          const SizedBox(height: 28),
          _SectionHeading(title: 'Day trade encerradas (${closed.length})'),
          const SizedBox(height: 12),
          if (closed.isEmpty)
            const _EmptyState(
              icon: Icons.history,
              title: 'Nenhuma operação encerrada',
              message: 'Seu histórico de P&L aparecerá aqui.',
            )
          else
            ...closed.map((order) => _OrderTile(order: order)),
        ],
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 24, wide ? 32 : 20, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!wide) ...[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(subtitle),
                const SizedBox(height: 22),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    final error = controller.quoteError;
    if (error == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5DB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D995)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF8B6615)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Color(0xFF684D13)),
            ),
          ),
          TextButton(
            onPressed: controller.isRefreshingQuotes
                ? null
                : controller.refreshQuotes,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.action,
    this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                  if (action != null)
                    TextButton(onPressed: onTap, child: Text(action!)),
                ],
              ),
              const SizedBox(height: 18),
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _QuoteList extends StatelessWidget {
  const _QuoteList({required this.quotes});

  final List<AssetQuote> quotes;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < quotes.length; index++) ...[
            _QuoteRow(
              quote: quotes[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AssetDetailsScreen(quote: quotes[index]),
                ),
              ),
            ),
            if (index != quotes.length - 1) const Divider(height: 1),
          ],
          if (quotes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Não há cotações para exibir.'),
            ),
        ],
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.quote, this.onTap});

  final AssetQuote quote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final positive = quote.changePercent >= 0;
    final color = positive ? const Color(0xFF087F5B) : const Color(0xFFBF5D42);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFEAF5EF),
        child: Text(
          quote.symbol.substring(0, 1),
          style: const TextStyle(
            color: Color(0xFF087F5B),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        quote.symbol,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          if (quote.name != null) quote.name!,
          'Máx. ${quote.dayHigh == null ? '—' : formatCurrency(quote.dayHigh!)}'
              ' · Mín. ${quote.dayLow == null ? '—' : formatCurrency(quote.dayLow!)}',
        ].join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatCurrency(quote.price),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            '${positive ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DayTradeTile extends StatelessWidget {
  const _DayTradeTile({required this.order});

  final TradeOrder order;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TradeSimController>();
    final quote = controller.quoteFor(order.symbol);
    final unrealizedPnl = quote == null
        ? null
        : (quote.price - order.price) * order.quantity;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.bolt)),
        title: Text('${order.symbol} · ${order.quantity} ações'),
        subtitle: Text(
          quote == null
              ? 'Entrada ${formatCurrency(order.price)} · cotação atual não carregada'
              : 'Entrada ${formatCurrency(order.price)} · P&L atual ${formatCurrency(unrealizedPnl!)}',
        ),
        isThreeLine: true,
        trailing: FilledButton.tonal(
          onPressed: quote == null
              ? null
              : () => _runAction(
                  context,
                  controller.closeDayTrade(order, quote.price),
                  successMessage:
                      'Posição encerrada em ${formatCurrency(quote.price)}.',
                ),
          child: const Text('Encerrar'),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final TradeOrder order;

  @override
  Widget build(BuildContext context) {
    final color = order.realizedPnl == null
        ? Theme.of(context).colorScheme.onSurface
        : order.realizedPnl! >= 0
        ? const Color(0xFF087F5B)
        : const Color(0xFFBF5D42);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            order.type == TradeType.day ? Icons.bolt : Icons.show_chart,
          ),
        ),
        title: Text('${order.symbol} · ${order.quantity} ações'),
        subtitle: Text(
          '${order.type == TradeType.day ? 'Day trade' : 'Swing trade'} · ${order.side == OrderSide.buy ? 'Compra' : 'Venda'} · ${formatDate(order.openedAt)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(order.price),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (order.realizedPnl != null)
              Text(
                'P&L ${formatCurrency(order.realizedPnl!)}',
                style: TextStyle(color: color, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: const Color(0xFF71837B)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<void> _showTransferDialog(
  BuildContext context,
  WalletTransactionType type,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _TransferDialog(type: type),
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.type});

  final WalletTransactionType type;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.type == WalletTransactionType.deposit;
    return AlertDialog(
      title: Text(isDeposit ? 'Simular depósito' : 'Simular saque'),
      content: TextField(
        controller: _amountController,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Valor em reais',
          prefixText: 'R\$ ',
          hintText: '100,00',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(isDeposit ? 'Depositar' : 'Sacar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = parseAmount(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }

    setState(() => _isSubmitting = true);
    final isDeposit = widget.type == WalletTransactionType.deposit;
    try {
      await context.read<TradeSimController>().transfer(
        type: widget.type,
        amount: amount,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDeposit
                ? 'Depósito simulado adicionado.'
                : 'Saque simulado realizado.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

Future<void> _runAction(
  BuildContext context,
  Future<void> action, {
  String? successMessage,
}) async {
  try {
    await action;
    if (successMessage != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    }
  } on Exception catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }
}

double _cardWidth(double totalWidth, int columns) {
  if (columns == 1) return totalWidth;
  return (totalWidth - (columns - 1) * 16) / columns;
}

double? parseAmount(String value) {
  var normalized = value.trim().replaceAll(' ', '');
  if (normalized.contains(',')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(normalized);
}

String formatCurrency(double value) {
  final fixed = value.abs().toStringAsFixed(2).split('.');
  final integer = fixed.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final sign = value < 0 ? '-' : '';
  return '${sign}R\$ $integer,${fixed.last}';
}

String formatDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} às $hour:$minute';
}
