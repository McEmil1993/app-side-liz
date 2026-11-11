import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'pickup_detail_screen.dart';
import 'home_screens.dart';
import 'widgets.dart';
import 'maps/address_map.dart';
import 'connected_profile_screen.dart';

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pending = app.assigned
        .where((p) => p.status == PickupStatus.awaitingConfirmation)
        .toList();
    final records = app.pickups
        .where(
          (p) =>
              p.buyerId == app.user.id &&
              [
                PickupStatus.completed,
                PickupStatus.disputed,
              ].contains(p.status),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Collection summary',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONFIRMED COLLECTIONS',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              Text(
                '${kg(app.history.fold<double>(0, (sum, p) => sum + (p.actualKg ?? 0)))} kg',
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${money(app.history.fold<double>(0, (sum, p) => sum + p.amount))} paid to households',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SectionTitle('Waiting for confirmation'),
        if (pending.isEmpty)
          const EmptyState(
            'All caught up',
            'After recording a collection, the household must confirm the weight and cash received.',
          ),
        ...pending.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PickupCard(pickup: p),
          ),
        ),
        const SectionTitle('Collection history'),
        if (records.isEmpty)
          const EmptyState(
            'No collection records',
            'Your completed and disputed collections appear here.',
          ),
        ...records.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PickupCard(pickup: p),
          ),
        ),
      ],
    );
  }
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final conversations = app.pickups
        .where(
          (p) => app.connected
              ? p.buyerId != null &&
                    (p.ownerId == app.user.id || p.buyerId == app.user.id)
              : app.role == UserRole.household
              ? p.ownerId == app.user.id &&
                    (p.buyerId != null ||
                        app.offers.any((o) => o.pickupId == p.id))
              : p.buyerId == app.user.id ||
                    app.offers.any(
                      (o) => o.pickupId == p.id && o.buyerId == app.user.id,
                    ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Your conversations',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          app.connected
              ? 'Private conversations for your assigned pickups.'
              : 'Local demo messages. Switch roles to reply.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        if (conversations.isEmpty)
          const EmptyState(
            'No conversations yet',
            'Send an offer or accept a buyer to start a conversation.',
          ),
        ...conversations.map((p) {
          final messages = app.messages
              .where((m) => m.pickupId == p.id)
              .toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Surface(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.mint,
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.green,
                  ),
                ),
                title: Text(
                  app.role == UserRole.household
                      ? p.buyerName ?? 'Buyer offers'
                      : p.ownerName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  messages.isEmpty
                      ? '${p.category} pickup · Start conversation'
                      : messages.last.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(pickupId: p.id),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String pickupId;
  const ChatScreen({super.key, required this.pickupId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final text = TextEditingController();
  final scroll = ScrollController();
  int _lastMessageCount = -1;
  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context),
        pickup = AppScope.of(context).pickup(widget.pickupId);
    final messages = app.messages
        .where((m) => m.pickupId == widget.pickupId)
        .toList();
    if (_lastMessageCount != messages.length) {
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.jumpTo(scroll.position.maxScrollExtent);
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          app.role == UserRole.household
              ? pickup.buyerName ?? 'Buyer conversation'
              : pickup.ownerName,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.mint,
              child: Text(
                '${pickup.category} pickup · Private conversation',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.darkGreen,
                ),
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: EmptyState(
                        'Say hello',
                        'Coordinate pickup details here.',
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(18),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final m = messages[i];
                        final own = m.senderId == app.user.id;
                        return Align(
                          alignment: own
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 280),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: own ? AppColors.green : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: own ? AppColors.green : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.text,
                                  style: TextStyle(
                                    color: own ? Colors.white : AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.pending
                                      ? 'Sending...'
                                      : clockLabel(m.sentAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: own
                                        ? Colors.white70
                                        : AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: app.busy
                        ? null
                        : () async {
                            if (text.text.trim().isEmpty) return;
                            final sent = await perform(
                              context,
                              () => app.sendMessage(
                                widget.pickupId,
                                text.text.trim(),
                              ),
                            );
                            if (sent && mounted) text.clear();
                          },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), user = AppScope.of(context).user;
    if (app.connected) return const ConnectedProfileScreen();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Surface(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.mint,
                child: Icon(
                  Icons.person_outline,
                  color: AppColors.green,
                  size: 42,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user.role.label,
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${user.barangay}, ${user.cityMunicipality}, Bohol',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (user.role == UserRole.buyer) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      user.buyerVerified
                          ? Icons.verified
                          : Icons.pending_outlined,
                      color: AppColors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        user.buyerVerified
                            ? 'Verified buyer · Demo status'
                            : 'Buyer verification pending · Demo',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SectionTitle('Your map location'),
        AddressMap(
          userLocation: true,
          address: user.mapAddress,
          savedPin: app.profilePin,
          onSave: app.saveProfilePin,
          title: user.role == UserRole.buyer
              ? 'Route starting point'
              : 'Default pickup pin',
        ),
        const SectionTitle('Account information'),
        Surface(
          child: Column(
            children: [
              DetailRow('Username', '@${user.username}'),
              DetailRow('Email', user.email),
              DetailRow('Contact', user.contact),
              DetailRow('Street / Purok', user.streetPurok),
            ],
          ),
        ),
        const SectionTitle('Your recycling activity'),
        Surface(
          child: Column(
            children: [
              DetailRow('Completed pickups', '${app.history.length}'),
              DetailRow(
                'Recyclables collected',
                '${kg(app.history.fold<double>(0, (sum, p) => sum + (p.actualKg ?? 0)))} kg',
              ),
            ],
          ),
        ),
        const SectionTitle('Demo account'),
        const Surface(
          child: Text(
            'You are signed in to a local demo account. Accounts and activity stay in memory and reset when the app restarts or the browser is refreshed. Backend authentication and buyer verification are not connected yet.',
            style: TextStyle(color: AppColors.muted, height: 1.6, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            app.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 20),
        const Center(child: BrandMark()),
        const SizedBox(height: 8),
        const Text(
          'Recycle locally. Make a difference.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool refreshing = false;

  Future<void> refresh() async {
    final app = AppScope.of(context);
    if (refreshing || app.busy) return;
    setState(() => refreshing = true);
    await perform(context, app.refresh);
    if (mounted) setState(() => refreshing = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = AppScope.of(context);
      if (app.connected) refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final notices = app.notices.where((n) => n.role == app.role).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (app.connected)
            IconButton(
              tooltip: 'Refresh announcements and notifications',
              onPressed: app.busy || refreshing ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (app.connected && (app.busy || refreshing))
            const LinearProgressIndicator(),
          Text(
            app.connected
                ? 'Pickup updates and LGU announcements. Refresh to check for new updates.'
                : 'In-app demo updates · Push notifications are not connected.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (notices.isEmpty && !app.busy && !refreshing)
            const EmptyState(
              'No updates yet',
              'Published LGU announcements for Everyone or your role will appear here. Draft, archived and expired announcements are hidden.',
            ),
          ...notices.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Surface(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.mint,
                    child: Icon(
                      n.announcementAudience == null
                          ? Icons.notifications_outlined
                          : Icons.campaign_outlined,
                      color: AppColors.green,
                    ),
                  ),
                  title: Text(
                    n.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (n.announcementAudience != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'LGU announcement · ${switch (n.announcementAudience) {
                              'household' => 'Household',
                              'buyer' => 'Scrap Buyer',
                              _ => 'Everyone',
                            }}',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Text(n.message),
                    ],
                  ),
                  onTap: n.pickupId == null
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PickupDetailScreen(pickupId: n.pickupId!),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
