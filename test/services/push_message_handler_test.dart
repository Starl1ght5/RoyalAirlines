import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:royal_airlines/services/push_message_handler.dart';

class FakeMessageSource implements PushMessageSource {
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  PushMessage? initial;

  @override
  Stream<PushMessage> get onMessage => foreground.stream;

  @override
  Stream<PushMessage> get onOpened => opened.stream;

  @override
  Future<PushMessage?> getInitial() async => initial;
}

const offerData = {
  'type': 'offer',
  'flightId': 'f1',
  'origin': 'BOG',
  'destination': 'CTG',
  'departureDate': '2026-11-20',
};

const offerMessage = PushMessage(
  title: 'Oferta BOG → CTG: 25% OFF',
  body: 'Sale el 20 de nov.',
  data: offerData,
);

void main() {
  late FakeMessageSource source;
  late List<OfferPushPayload> opened;
  late List<PushMessage> banners;
  late List<void Function()> bannerTaps;
  late PushMessageHandler handler;

  setUp(() {
    source = FakeMessageSource();
    opened = [];
    banners = [];
    bannerTaps = [];
    handler = PushMessageHandler(
      source: source,
      openOffer: (payload) async => opened.add(payload),
      showBanner: (message, payload, onOpen) {
        banners.add(message);
        bannerTaps.add(onOpen);
      },
    )..init();
  });

  tearDown(() => handler.dispose());

  group('OfferPushPayload', () {
    test('lee una oferta completa', () {
      final payload = OfferPushPayload.tryParse(offerData)!;

      expect(payload.origin, 'BOG');
      expect(payload.destination, 'CTG');
      expect(payload.flightId, 'f1');
      expect(payload.departureDate, DateTime(2026, 11, 20));
    });

    test('ignora mensajes que no son ofertas o vienen incompletos', () {
      expect(OfferPushPayload.tryParse({'type': 'promo', 'origin': 'BOG', 'destination': 'CTG'}), isNull);
      expect(OfferPushPayload.tryParse({'type': 'offer', 'origin': 'BOG'}), isNull);
      expect(OfferPushPayload.tryParse(const {}), isNull);
    });

    test('la fecha y el vuelo son opcionales', () {
      final payload = OfferPushPayload.tryParse(
          {'type': 'offer', 'origin': 'bog', 'destination': 'ctg', 'departureDate': 'basura'})!;

      expect(payload.origin, 'BOG');
      expect(payload.departureDate, isNull);
      expect(payload.flightId, isNull);
    });
  });

  group('primer plano', () {
    test('con sesión muestra el aviso y "VER" abre la oferta', () async {
      handler.onSession(authenticated: true, restoring: false);

      source.foreground.add(offerMessage);
      await pumpEventQueue();

      expect(banners, hasLength(1));
      expect(opened, isEmpty);
      bannerTaps.single();
      expect(opened.single.destination, 'CTG');
    });

    test('sin sesión no muestra nada', () async {
      source.foreground.add(offerMessage);
      await pumpEventQueue();

      expect(banners, isEmpty);
    });

    test('ignora mensajes que no son ofertas', () async {
      handler.onSession(authenticated: true, restoring: false);

      source.foreground.add(const PushMessage(data: {'type': 'otro'}));
      await pumpEventQueue();

      expect(banners, isEmpty);
    });
  });

  group('al tocar la notificación', () {
    test('en segundo plano con sesión abre la búsqueda de inmediato', () async {
      handler.onSession(authenticated: true, restoring: false);

      source.opened.add(offerMessage);
      await pumpEventQueue();

      expect(opened, hasLength(1));
      expect(opened.single.origin, 'BOG');
    });

    test('con la app cerrada espera a que la sesión se restaure', () async {
      source.opened.add(offerMessage); // llega mientras se restaura la sesión
      await pumpEventQueue();
      expect(opened, isEmpty);

      handler.onSession(authenticated: false, restoring: true);
      expect(opened, isEmpty);

      handler.onSession(authenticated: true, restoring: false);
      expect(opened, hasLength(1));

      handler.onSession(authenticated: true, restoring: false); // otro notify: no repite
      expect(opened, hasLength(1));
    });

    test('si la restauración termina sin sesión, descarta lo pendiente', () async {
      source.opened.add(offerMessage);
      await pumpEventQueue();

      handler.onSession(authenticated: false, restoring: false);
      handler.onSession(authenticated: true, restoring: false); // inicia sesión después

      expect(opened, isEmpty);
    });
  });

  test('el mensaje inicial (app cerrada) se trata como una notificación tocada', () async {
    final cold = FakeMessageSource()..initial = offerMessage;
    final coldOpened = <OfferPushPayload>[];
    final coldHandler = PushMessageHandler(
      source: cold,
      openOffer: (payload) async => coldOpened.add(payload),
      showBanner: (_, __, ___) {},
    )..init();

    await pumpEventQueue();
    expect(coldOpened, isEmpty);

    coldHandler.onSession(authenticated: true, restoring: false);
    expect(coldOpened.single.destination, 'CTG');
    await coldHandler.dispose();
  });
}
