import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/tracking/presentation/reparto_provider.dart';

class ShellPrincipal extends ConsumerWidget {
  const ShellPrincipal({
    super.key,
    required this.navigationShell,
    required this.esRepartidor,
  });

  final StatefulNavigationShell navigationShell;
  final bool esRepartidor;

  static const _destinosCliente = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Pedidos',
    ),
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'Seguimiento',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];

  static const _destinosRepartidor = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.local_shipping_outlined),
      selectedIcon: Icon(Icons.local_shipping),
      label: 'Entregas',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route),
      label: 'Recorrido',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: 'Rendimiento',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Solo el repartidor emite ubicación, así que solo él puede tener un
          // reparto en curso del que avisar.
          if (esRepartidor) const _BannerReparto(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            // `initialLocation: true` al volver a tocar la pestaña activa
            // reinicia esa rama, en lugar de dejarla en una subpantalla.
            onDestinationSelected: (indice) => navigationShell.goBranch(
              indice,
              initialLocation: indice == navigationShell.currentIndex,
            ),
            destinations:
                esRepartidor ? _destinosRepartidor : _destinosCliente,
          ),
        ],
      ),
    );
  }
}

class _BannerReparto extends ConsumerWidget {
  const _BannerReparto();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reparto = ref.watch(repartoProvider);
    if (!reparto.enServicio || reparto.pedidoId == null) {
      return const SizedBox.shrink();
    }

    final conectado = reparto.conectado;
    final color = conectado ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);

    return Material(
      color: color.withOpacity(0.12),
      child: InkWell(
        onTap: () => context.push('/reparto/${reparto.pedidoId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(conectado ? Icons.gps_fixed : Icons.gps_not_fixed,
                  size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conectado
                      ? 'Reparto en curso · pedido ${reparto.pedidoId} · '
                          '${reparto.puntosEnviados} puntos'
                      : 'Reparto en curso · reconectando…',
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.95)),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(repartoProvider.notifier).detener(),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Detener'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
