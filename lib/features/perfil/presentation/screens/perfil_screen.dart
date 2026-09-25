import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/map_style.dart';
import '../../../../shared/models/usuario.dart';
import '../../../../shared/widgets/estados_vista.dart';
import '../../../../shared/widgets/mapa/piezas_mapa.dart';
import '../../../../shared/widgets/piezas_pedido.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../direcciones/presentation/screens/mis_direcciones_screen.dart';
import '../perfil_provider.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: perfil.when(
        loading: () => const ListaEsqueleto(filas: 3),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(perfilProvider),
        ),
        data: (usuario) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(perfilProvider);
            await ref.read(perfilProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(MapStyle.esp4),
            children: [
              _Cabecera(usuario: usuario),
              const SizedBox(height: MapStyle.esp5),

              SeccionTarjeta(
                titulo: 'Datos de contacto',
                child: Column(
                  children: [
                    FilaDato('Correo', usuario.email, icono: Icons.mail_outline),
                    if (usuario.tieneTelefono)
                      FilaDato('Teléfono', usuario.telefono!,
                          icono: Icons.phone_outlined),
                  ],
                ),
              ),

              if (usuario.esRepartidor) ...[
                const SizedBox(height: MapStyle.esp5),
                _BloqueRepartidor(usuario: usuario),
              ],

              if (usuario.esCliente) ...[
                const SizedBox(height: MapStyle.esp5),
                _Opcion(
                  icono: Icons.place_outlined,
                  titulo: 'Mis direcciones',
                  subtitulo: 'Gestiona dónde recoges y recibes',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const MisDireccionesScreen()),
                  ),
                ),
              ],

              const SizedBox(height: MapStyle.esp3),
              _Opcion(
                icono: Icons.notifications_none,
                titulo: 'Notificaciones',
                subtitulo: 'Avisos de tus pedidos',
                onTap: () => context.push('/notificaciones'),
              ),

              const SizedBox(height: MapStyle.esp6),
              OutlinedButton.icon(
                onPressed: () => _cerrarSesion(context, ref),
                icon: const Icon(Icons.logout, size: 19),
                label: const Text('Cerrar sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MapStyle.peligro,
                  side: BorderSide(color: MapStyle.peligro.withOpacity(0.4)),
                ),
              ),
              const SizedBox(height: MapStyle.esp6),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión para entrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            style: FilledButton.styleFrom(backgroundColor: MapStyle.peligro),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    // El router devuelve al login al caer el estado de sesión; y el
    // `repartoProvider` corta la emisión de GPS al escuchar ese mismo cambio.
    if (confirmado == true) await ref.read(authProvider.notifier).logout();
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final calificacion = usuario.perfilRepartidor?.calificacionPromedio;

    return Column(
      children: [
        AvatarUsuario(usuario: usuario, radio: 44),
        const SizedBox(height: MapStyle.esp3),
        Text(
          usuario.nombreCompleto,
          textAlign: TextAlign.center,
          style: MapStyle.titulo,
        ),
        const SizedBox(height: MapStyle.esp2),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: MapStyle.esp2,
          runSpacing: MapStyle.esp2,
          children: [
            ChipEstado(
              texto: usuario.esRepartidor ? 'Repartidor' : 'Cliente',
              color: MapStyle.primario,
            ),
            if (calificacion != null && calificacion > 0)
              PildoraMetrica(
                icono: Icons.star_rounded,
                texto: '${calificacion.toStringAsFixed(1)} de 5',
              ),
          ],
        ),
      ],
    );
  }
}

class _BloqueRepartidor extends ConsumerWidget {
  const _BloqueRepartidor({required this.usuario});

  final Usuario usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = usuario.perfilRepartidor;
    final disponible = ref.watch(disponibilidadProvider);

    return Column(
      children: [
        SeccionTarjeta(
          titulo: 'Disponibilidad',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: disponible.valueOrNull ?? false,
            onChanged: disponible.isLoading
                ? null
                : (valor) async {
                    final error = await ref
                        .read(disponibilidadProvider.notifier)
                        .cambiar(valor);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
            title: Text(
              (disponible.valueOrNull ?? false) ? 'Disponible' : 'No disponible',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MapStyle.textoFuerte,
              ),
            ),
            subtitle: Text(
              (disponible.valueOrNull ?? false)
                  ? 'Puedes recibir nuevas entregas'
                  : 'No se te asignarán entregas nuevas',
              style: MapStyle.secundario,
            ),
          ),
        ),

        if (perfil != null && perfil.tieneVehiculo) ...[
          const SizedBox(height: MapStyle.esp5),
          SeccionTarjeta(
            titulo: 'Vehículo',
            child: Column(
              children: [
                if (perfil.tipoVehiculo != null)
                  FilaDato('Tipo', perfil.tipoVehiculo!,
                      icono: Icons.two_wheeler_outlined),
                if (perfil.placa != null)
                  FilaDato('Placa', perfil.placa!,
                      icono: Icons.confirmation_number_outlined),
                if (perfil.licencia != null)
                  FilaDato('Licencia', perfil.licencia!,
                      icono: Icons.badge_outlined),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MapStyle.esp4,
          vertical: MapStyle.esp2 - 4,
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: MapStyle.primario.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icono, size: 19, color: MapStyle.primario),
        ),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right, color: MapStyle.neutro),
      ),
    );
  }
}
