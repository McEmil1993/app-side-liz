import 'package:flutter/material.dart';
import '../data/recycling_repository.dart';
import '../data/auth_repository.dart';
import '../data/demo_auth_repository.dart';
import '../domain/registration.dart';
import '../domain/map_location.dart';
import '../domain/models.dart';

class AppController extends ChangeNotifier {
  final RecyclingRepository repository;
  final DateTime Function() _clock;
  final AuthRepository authRepository;
  AppController(
    this.repository, {
    AuthRepository? authRepository,
    DateTime Function()? clock,
  }) : authRepository = authRepository ?? DemoAuthRepository(),
       _clock = clock ?? DateTime.now {
    if (repository.remote) notices.clear();
  }
  bool get connected => authRepository is AccountRepository;
  AccountRepository get account => authRepository as AccountRepository;
  List<String> get catalog => repository.availableCategories;
  bool starting = false;
  String? startupError, dataError;
  Future<void> initialize() async {
    starting = true;
    startupError = null;
    notifyListeners();
    try {
      if (connected) {
        _currentUser = await account.restoreSession();
        if (_currentUser != null) {
          final pin = account.profilePin;
          if (pin != null) _profilePins[user.id] = pin;
          await refresh();
        }
      } else {
        await refresh();
      }
    } catch (error) {
      startupError = error.toString();
    } finally {
      starting = false;
      notifyListeners();
    }
  }

  DateTime get now => _clock();
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  UserRole? get role => _currentUser?.role;
  bool authBusy = false;
  final Map<String, GeoPin> _profilePins = {};
  GeoPin? get profilePin => _profilePins[user.id];
  Future<void> saveProfilePin(GeoPin pin) async {
    if (!pin.valid) throw StateError('Choose a valid map pin.');
    final updated = user.withPinAddress(pin);
    if (connected) {
      _currentUser = await account.savePin(updated, pin);
    } else {
      _currentUser = updated;
    }
    _profilePins[user.id] = pin;
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, Object?> values) async {
    if (!connected) {
      throw StateError('This feature requires the API connection.');
    }
    _currentUser = await account.updateProfile(values);
    if (account.profilePin == null) {
      _profilePins.remove(user.id);
    } else {
      _profilePins[user.id] = account.profilePin!;
    }
    notifyListeners();
  }

  Future<void> updateAvatar(String uri) async {
    _currentUser = await account.updateAvatar(uri);
    notifyListeners();
  }

  Future<void> changePassword(String current, String password) async {
    await account.changePassword(current, password);
    expireSession();
  }

  void expireSession() {
    _currentUser = null;
    if (connected) {
      pickups = [];
      offers = [];
      messages = [];
      _liveMessages.clear();
      _pendingMessages.clear();
      notices.clear();
      _profilePins.clear();
    }
    notifyListeners();
  }

  List<Pickup> pickups = [];
  List<Offer> offers = [];
  List<ChatMessage> messages = [];
  final Map<String, ChatMessage> _liveMessages = {};
  final Map<String, ChatMessage> _pendingMessages = {};
  int _messageSequence = 0;
  bool busy = false;
  final List<AppNotice> notices = [
    const AppNotice(
      'Welcome to EasyScrap',
      'Your recyclable materials can make a difference. Start with a pickup request.',
      UserRole.household,
    ),
    const AppNotice(
      'Your route is ready',
      'Three sample pickups are ready for collection.',
      UserRole.buyer,
    ),
  ];
  AppUser get user =>
      _currentUser ?? (throw StateError('Please log in first.'));
  List<Pickup> get ownPickups =>
      pickups.where((pickup) => pickup.ownerId == user.id).toList();
  List<Pickup> get assigned =>
      pickups
          .where(
            (pickup) =>
                pickup.buyerId == user.id &&
                ![
                  PickupStatus.completed,
                  PickupStatus.cancelled,
                  PickupStatus.disputed,
                ].contains(pickup.status),
          )
          .toList()
        ..sort((a, b) => a.windowStart.compareTo(b.windowStart));
  List<Pickup> get marketplace =>
      pickups.where((pickup) => pickup.status == PickupStatus.open).toList();
  List<Pickup> get history => pickups
      .where(
        (pickup) =>
            (role == UserRole.household
                ? pickup.ownerId == user.id
                : pickup.buyerId == user.id) &&
            pickup.status == PickupStatus.completed,
      )
      .toList();
  Pickup pickup(String id) => pickups.firstWhere((pickup) => pickup.id == id);
  Future<void> _authenticate(Future<AppUser> Function() action) async {
    if (authBusy) return;
    authBusy = true;
    notifyListeners();
    try {
      _currentUser = await action();
      if (connected) {
        final pin = account.profilePin;
        if (pin != null) _profilePins[user.id] = pin;
        try {
          await refresh();
        } catch (_) {}
      }
      final saved = _profilePins[user.id];
      if (saved != null) _currentUser = user.withPinAddress(saved);
    } finally {
      authBusy = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String identifier, String password) =>
      _authenticate(() => authRepository.signIn(identifier, password));
  Future<void> register(Registration registration) =>
      _authenticate(() => authRepository.register(registration));

  Future<void> signOut() async {
    expireSession();
    if (connected) {
      try {
        await account.signOut();
      } catch (_) {}
    }
  }

  Future<void> refresh() async {
    dataError = null;
    try {
      pickups = await repository.loadPickups();
      offers = await repository.loadOffers();
      final loaded = await repository.loadMessages();
      final ids = loaded.map((m) => m.id).where((id) => id.isNotEmpty).toSet();
      _liveMessages.removeWhere((id, _) => ids.contains(id));
      messages = [
        ...loaded,
        ..._liveMessages.values,
        ..._pendingMessages.values,
      ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      if (connected && _currentUser != null) {
        _currentUser = await account.loadProfile();
        final pin = account.profilePin;
        if (pin == null) {
          _profilePins.remove(user.id);
        } else {
          _profilePins[user.id] = pin;
        }
        notices
          ..clear()
          ..addAll(repository.remoteNotices);
      }
    } catch (error) {
      dataError = error.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) throw StateError('Please wait for the current action.');
    busy = true;
    notifyListeners();
    try {
      await action();
      await refresh();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> publish(Pickup pickup) =>
      _run(() => repository.publish(user, pickup));
  Future<void> updatePickupPin(String id, GeoPin pin) =>
      _run(() => repository.updateLocationPin(user, id, pin));
  Future<void> sendOffer(String id, double price) => _run(() async {
    await repository.sendOffer(user, id, price);
    if (!connected) {
      notices.insert(
        0,
        AppNotice(
          'New buyer offer',
          '${user.name} sent an offer for your recyclable materials.',
          UserRole.household,
          pickupId: id,
        ),
      );
    }
  });
  Future<void> selectOffer(String id) =>
      _run(() => repository.selectOffer(user, id));
  Future<void> advance(String id) =>
      _run(() => repository.advancePickup(user, id));
  Future<void> collect(String id, double kg, double price, bool paid) =>
      _run(() async {
        await repository.recordCollection(user, id, kg, price, paid);
        if (!connected) {
          notices.insert(
            0,
            AppNotice(
              'Please confirm collection',
              'Review the actual weight and payment details.',
              UserRole.household,
              pickupId: id,
            ),
          );
        }
      });
  Future<void> confirm(String id, bool accepted) =>
      _run(() => repository.confirmCollection(user, id, accepted: accepted));
  Future<void> cancel(String id) =>
      _run(() => repository.cancelPickup(user, id));
  void receiveChatMessage(ChatMessage message) {
    if (_currentUser == null || message.id.isEmpty) return;
    if (!pickups.any(
      (p) =>
          p.id == message.pickupId &&
          (p.ownerId == user.id || p.buyerId == user.id),
    )) {
      return;
    }
    _liveMessages[message.id] = message;
    if (_liveMessages.length > 500) {
      _liveMessages.remove(_liveMessages.keys.first);
    }
    messages = [...messages.where((m) => m.id != message.id), message]
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    notifyListeners();
  }

  Future<void> sendMessage(String id, String text) async {
    if (busy) throw StateError('Please wait for the current action.');
    final body = text.trim();
    if (body.isEmpty || body.length > 1000) {
      throw StateError('Message must be between 1 and 1000 characters.');
    }
    final actor = user;
    final pendingId = 'local-${++_messageSequence}';
    final pending = ChatMessage(
      id: pendingId,
      pickupId: id,
      senderId: actor.id,
      text: body,
      sentAt: now,
      pending: true,
    );
    _pendingMessages[pendingId] = pending;
    messages = [...messages, pending];
    busy = true;
    notifyListeners();
    try {
      final saved = await repository.sendMessage(actor, id, body);
      if (_currentUser?.id != actor.id) return;
      _pendingMessages.remove(pendingId);
      messages.removeWhere((m) => m.id == pendingId);
      receiveChatMessage(saved);
    } catch (_) {
      _pendingMessages.remove(pendingId);
      messages.removeWhere((m) => m.id == pendingId);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
