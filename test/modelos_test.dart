// Pruebas del parseo y de las reglas que se derivan de él.
//
// El modelo `Pedido` tenía seis campos y ahora lee la respuesta entera del
// backend; estas pruebas fijan la forma real del JSON de DRF —decimales como
// texto, relaciones anidadas, listas opcionales— para que un cambio en el
// serializer se note aquí y no en una pantalla en blanco.
import 'package:flutter_test/flutter_test.dart';
import 'package:movil_logistica/shared/models/direccion.dart';
import 'package:movil_logistica/shared/models/notificacion.dart';
import 'package:movil_logistica/shared/models/pedido.dart';
import 'package:movil_logistica/shared/models/rendimiento.dart';
import 'package:movil_logistica/shared/models/usuario.dart';

Map<String, dynamic> _direccion(int id, {String calle = 'Av. Arequipa'}) => {
      'id': id,
      'calle': calle,
      'numero': '1234',
      'distrito': 'Lince',
      'ciudad': 'Lima',
      'referencia': null,
      'latitud': -12.09,
      'longitud': -77.04,
      'es_default': false,
    };

Map<String, dynamic> _pedidoJson({
  String estado = 'en_camino',
  List<Map<String, dynamic>>? historial,
  Map<String, dynamic>? calificacion,
  List<Map<String, dynamic>>? transiciones,
}) =>
    {
      'id': 7,
      'codigo_seguimiento': 'ABC123',
      'estado': {'id': 4, 'codigo': estado, 'nombre': 'En camino', 'orden': 4},
      'cliente': {
        'id': 1,
        'email': 'ana@x.com',
        'nombre': 'Ana',
        'apellido': 'Pérez',
        'rol': 'cliente',
        'telefono': '999888777',
      },
      'repartidor': null,
      'direccion_origen': _direccion(1, calle: 'Almacén'),
      'direccion_destino': _direccion(2),
      'descripcion': 'Documentos',
      // DRF serializa los DecimalField como texto.
      'peso_kg': '2.50',
      'costo_envio': '15.00',
      'fecha_creacion': '2026-03-01T10:00:00Z',
      'fecha_estimada_entrega': null,
      'fecha_entrega_real': null,
      'historial': historial ?? [],
      'transiciones_permitidas': transiciones ?? [],
      'calificacion': calificacion,
    };

void main() {
  group('Pedido', () {
    test('lee los decimales que DRF manda como texto', () {
      final pedido = Pedido.fromJson(_pedidoJson());

      expect(pedido.pesoKg, 2.5);
      expect(pedido.costoEnvio, 15.0);
    });

    test('sin estado no revienta: cae en el estado desconocido', () {
      // El alta de pedido respondía con el serializer de escritura, que no
      // lleva `estado`, y el cast a pelo tumbaba la pantalla entera con
      // «type 'Null' is not a subtype of type 'Map<String, dynamic>'».
      // El backend ya devuelve la forma de lectura; esto es el cinturón.
      final json = _pedidoJson()..remove('estado');

      final pedido = Pedido.fromJson(json);

      expect(pedido.estado.codigo, '');
      expect(pedido.estado.nombre, 'Sin estado');
      expect(pedido.id, 7);
      expect(pedido.codigoSeguimiento, 'ABC123');
    });

    test('con estado presente lo lee tal cual', () {
      final pedido = Pedido.fromJson(_pedidoJson(estado: 'pendiente'));

      expect(pedido.estado.codigo, 'pendiente');
      expect(pedido.estado.id, 4);
    });

    test('expande cliente y direcciones', () {
      final pedido = Pedido.fromJson(_pedidoJson());

      expect(pedido.cliente?.nombreCompleto, 'Ana Pérez');
      expect(pedido.direccionDestino?.lineaCompleta,
          'Av. Arequipa 1234 · Lince · Lima');
      expect(pedido.repartidor, isNull);
      expect(pedido.tieneRepartidor, isFalse);
    });

    test('ordena el historial por fecha aunque llegue desordenado', () {
      final pedido = Pedido.fromJson(_pedidoJson(historial: [
        {
          'id': 2,
          'estado': {'id': 4, 'codigo': 'en_camino', 'nombre': 'En camino', 'orden': 4},
          'fecha': '2026-03-02T10:00:00Z',
          'comentario': null,
          'usuario': 3,
        },
        {
          'id': 1,
          'estado': {'id': 1, 'codigo': 'pendiente', 'nombre': 'Pendiente', 'orden': 1},
          'fecha': '2026-03-01T10:00:00Z',
          'comentario': null,
          'usuario': 1,
        },
      ]));

      expect(pedido.historial.map((h) => h.estado.codigo),
          ['pendiente', 'en_camino']);
    });

    test('solo ofrece cancelar si el backend lo permite', () {
      final sinTransiciones = Pedido.fromJson(_pedidoJson());
      expect(sinTransiciones.puedeCancelar, isFalse);

      final conCancelar = Pedido.fromJson(_pedidoJson(transiciones: [
        {'id': 6, 'codigo': 'cancelado', 'nombre': 'Cancelado', 'orden': 6},
      ]));
      expect(conCancelar.puedeCancelar, isTrue);
    });

    test('permite calificar solo una entrega sin calificación previa', () {
      final entregadoSinCalificar =
          Pedido.fromJson(_pedidoJson(estado: 'entregado'));
      expect(entregadoSinCalificar.puedeCalificar, isTrue);

      final yaCalificado = Pedido.fromJson(_pedidoJson(
        estado: 'entregado',
        calificacion: {
          'id': 1,
          'puntuacion': 5,
          'comentario': 'Muy rápido',
          'fecha': '2026-03-03T10:00:00Z',
        },
      ));
      expect(yaCalificado.puedeCalificar, isFalse);
      expect(yaCalificado.calificacion?.puntuacion, 5);

      // En camino todavía no hay nada que calificar.
      expect(Pedido.fromJson(_pedidoJson()).puedeCalificar, isFalse);
    });

    test('clasifica los estados terminales', () {
      expect(Pedido.fromJson(_pedidoJson(estado: 'entregado')).estaTerminado,
          isTrue);
      expect(Pedido.fromJson(_pedidoJson(estado: 'devuelto')).estaCancelado,
          isTrue);
      expect(Pedido.fromJson(_pedidoJson(estado: 'pendiente')).estaEnCurso,
          isTrue);
    });
  });

  group('Direccion', () {
    test('omite los campos vacíos al componer la línea', () {
      final direccion = Direccion.fromJson({
        'id': 1,
        'calle': 'Jr. Lampa',
        'numero': null,
        'distrito': 'Cercado',
        'ciudad': null,
        'latitud': 0.0,
        'longitud': 0.0,
        'es_default': true,
      });

      expect(direccion.lineaCompleta, 'Jr. Lampa · Cercado');
      // Sin alias, el título cae en la calle, que es el único campo obligatorio.
      expect(direccion.titulo, 'Jr. Lampa');
    });

    test('no envía el usuario al guardar', () {
      final cuerpo = Direccion.fromJson(_direccion(1)).toJson();

      // Lo fija la vista con el usuario autenticado; mandarlo desde el móvil
      // daría a entender que se puede elegir de quién es la dirección.
      expect(cuerpo.containsKey('usuario'), isFalse);
      expect(cuerpo['latitud'], -12.09);
    });
  });

  group('Usuario', () {
    test('lee el perfil de repartidor anidado', () {
      final usuario = Usuario.fromJson({
        'id': 3,
        'email': 'rep@x.com',
        'nombre': 'Beto',
        'apellido': 'Quispe',
        'rol': 'repartidor',
        'perfil_repartidor': {
          'id': 1,
          'tipo_vehiculo': 'Moto',
          'placa': 'ABC-123',
          'licencia': null,
          'disponible': false,
          'calificacion_promedio': '4.75',
        },
      });

      expect(usuario.esRepartidor, isTrue);
      expect(usuario.iniciales, 'BQ');
      expect(usuario.perfilRepartidor?.disponible, isFalse);
      expect(usuario.perfilRepartidor?.calificacionPromedio, 4.75);
      expect(usuario.perfilRepartidor?.tieneVehiculo, isTrue);
    });

    test('un cliente no trae perfil de repartidor', () {
      final usuario = Usuario.fromJson({
        'id': 1,
        'email': 'ana@x.com',
        'nombre': 'Ana',
        'apellido': 'Pérez',
        'rol': 'cliente',
        'perfil_repartidor': null,
      });

      expect(usuario.perfilRepartidor, isNull);
      expect(usuario.esCliente, isTrue);
    });
  });

  group('Rendimiento', () {
    test('no calcula puntualidad sin entregas con plazo', () {
      final datos = Rendimiento.fromJson({
        'repartidor': 'Beto Quispe',
        'total_entregas': 3,
        'entregas_a_tiempo': 0,
        'entregas_tardias': 0,
        'tiempo_promedio_min': null,
        'calificacion_promedio': null,
      });

      // Un 0 % sería mentir: ninguna de esas entregas tenía fecha estimada
      // contra la que compararse.
      expect(datos.proporcionATiempo, isNull);
      expect(datos.sinDatos, isFalse);
    });

    test('divide entre las entregas medidas, no entre el total', () {
      final datos = Rendimiento.fromJson({
        'repartidor': 'Beto',
        'total_entregas': 10,
        'entregas_a_tiempo': 3,
        'entregas_tardias': 1,
        'tiempo_promedio_min': 42.5,
        'calificacion_promedio': 4.0,
      });

      expect(datos.proporcionATiempo, 0.75);
      expect(datos.tiempoPromedioMin, 42.5);
    });
  });

  group('Notificacion', () {
    test('sobrevive a los campos opcionales vacíos', () {
      final aviso = Notificacion.fromJson({
        'id': 1,
        'usuario': 2,
        'pedido': null,
        'tipo': null,
        'titulo': null,
        'mensaje': null,
        'leido': false,
        'fecha_creacion': '2026-03-01T10:00:00Z',
      });

      expect(aviso.tituloVisible, 'Notificación');
      expect(aviso.mensajeVisible, '');
      expect(aviso.llevaAPedido, isFalse);
    });
  });
}
