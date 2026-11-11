import 'permissions_screen.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../data/upload_image.dart';
import '../domain/location.dart';
import '../domain/models.dart';
import '../domain/registration.dart';
import 'location_fields.dart';
import 'maps/address_map.dart';
import 'widgets.dart';

class ConnectedProfileScreen extends StatefulWidget {
  const ConnectedProfileScreen({super.key});
  @override
  State<ConnectedProfileScreen> createState() => _ConnectedProfileScreenState();
}

class _ConnectedProfileScreenState extends State<ConnectedProfileScreen> {
  bool picking = false;
  Future<void> chooseAvatar() async {
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw StateError('Choose an image smaller than 5 MB.');
      }
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AvatarEditorScreen(bytes: bytes),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context), user = app.user;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Surface(
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.mint,
                    backgroundImage: user.avatar == null
                        ? null
                        : MemoryImage(user.avatar!),
                    child: user.avatar == null
                        ? const Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppColors.green,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Change profile photo',
                      onPressed: picking ? null : chooseAvatar,
                      icon: picking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(),
                            )
                          : const Icon(Icons.camera_alt, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                user.role.label,
                style: const TextStyle(color: AppColors.green),
              ),
              const SizedBox(height: 8),
              Text(
                '${user.barangay}, ${user.cityMunicipality}, Bohol',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const EditMobileProfileScreen(),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
            ],
          ),
        ),
        if (user.role.name == 'buyer') ...[
          const SectionTitle('Buyer verification'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      user.buyerVerified
                          ? Icons.verified
                          : Icons.pending_outlined,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user.buyerVerified
                            ? 'Verified buyer'
                            : 'Status: ${user.verificationStatus.replaceAll('_', ' ')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'LGU approval is required before you can send offers.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const BuyerDocumentsScreen(),
                    ),
                  ),
                  child: Text(
                    user.buyerVerified
                        ? 'View verification'
                        : 'Documents / review status',
                  ),
                ),
              ],
            ),
          ),
        ],
        const SectionTitle('Your map location'),
        AddressMap(
          userLocation: true,
          address: user.mapAddress,
          savedPin: app.profilePin,
          onSave: app.saveProfilePin,
          title: user.role.name == 'buyer'
              ? 'Route starting point'
              : 'Default pickup pin',
        ),
        const SectionTitle('App settings'),
        Surface(
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('App permissions'),
            subtitle: const Text('Notifications, location, photos and files'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const PermissionsScreen(),
              ),
            ),
          ),
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
                'Collected',
                '${kg(app.history.fold<double>(0, (sum, p) => sum + (p.actualKg ?? 0)))} kg',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const MobilePasswordScreen(),
            ),
          ),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Change password'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.of(context).popUntil((route) => route.isFirst);
            await app.signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}

class AvatarEditorScreen extends StatefulWidget {
  final Uint8List bytes;
  const AvatarEditorScreen({super.key, required this.bytes});
  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  double zoom = 1;
  int turns = 0;
  bool saving = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit profile photo')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Center your photo, zoom and rotate before saving.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: ClipRect(
              child: RotatedBox(
                quarterTurns: turns,
                child: Transform.scale(
                  scale: zoom,
                  child: Image.memory(
                    widget.bytes,
                    fit: BoxFit.cover,
                    width: 300,
                    height: 300,
                  ),
                ),
              ),
            ),
          ),
        ),
        Slider(
          value: zoom,
          min: 1,
          max: 3,
          onChanged: saving ? null : (value) => setState(() => zoom = value),
        ),
        OutlinedButton.icon(
          onPressed: saving
              ? null
              : () => setState(() => turns = (turns + 1) % 4),
          icon: const Icon(Icons.rotate_right),
          label: const Text('Rotate'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  final app = AppScope.of(context);
                  setState(() => saving = true);
                  final saved = await perform(context, () async {
                    final uri = await prepareUploadImage(
                      widget.bytes,
                      square: true,
                      turns: turns,
                      zoom: zoom,
                    );
                    await app.updateAvatar(uri);
                  }, success: 'Profile photo updated.');
                  if (!context.mounted) return;
                  if (saved) {
                    Navigator.pop(context);
                  } else {
                    setState(() => saving = false);
                  }
                },
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save photo'),
        ),
      ],
    ),
  );
}

class EditMobileProfileScreen extends StatefulWidget {
  const EditMobileProfileScreen({super.key});
  @override
  State<EditMobileProfileScreen> createState() =>
      _EditMobileProfileScreenState();
}

class _EditMobileProfileScreenState extends State<EditMobileProfileScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  LocationSelection? location;
  bool initialized = false, saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      final user = AppScope.of(context).user;
      for (final entry in {
        'firstname': user.firstname,
        'middlename': user.middlename,
        'lastname': user.lastname,
        'suffix': user.suffix,
        'username': user.username,
        'email': user.email,
        'contact': user.contact,
        'street_purok': user.streetPurok,
      }.entries) {
        fields[entry.key] = TextEditingController(text: entry.value);
      }
      initialized = true;
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ...{
              'firstname': 'First name',
              'middlename': 'Middle name (optional)',
              'lastname': 'Last name',
              'suffix': 'Suffix (optional)',
              'username': 'Username',
              'email': 'Email',
              'contact': 'Contact',
              'street_purok': 'Street / Purok',
            }.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: fields[entry.key],
                  enabled: !saving,
                  maxLength: entry.key == 'email'
                      ? 254
                      : entry.key == 'suffix'
                      ? 20
                      : entry.key == 'street_purok'
                      ? 255
                      : 100,
                  decoration: InputDecoration(
                    labelText: entry.value,
                    counterText: '',
                  ),
                  validator: entry.key == 'email'
                      ? AccountValidation.email
                      : entry.key == 'contact'
                      ? AccountValidation.contact
                      : [
                          'middlename',
                          'suffix',
                          'street_purok',
                        ].contains(entry.key)
                      ? null
                      : AccountValidation.requiredName,
                ),
              ),
            ),
            const Text(
              'Region VII · Bohol',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            BoholLocationFields(
              initialCityCode: app.user.cityMunicipalityCode,
              initialBarangayCode: app.user.barangayCode,
              onChanged: (value) => location = value,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate() || location == null) {
                        return;
                      }
                      setState(() => saving = true);
                      final saved = await perform(
                        context,
                        () => app.updateProfile({
                          for (final entry in fields.entries)
                            entry.key:
                                ['middlename', 'suffix'].contains(entry.key) &&
                                    entry.value.text.trim().isEmpty
                                ? null
                                : entry.value.text.trim(),
                          ...app.user.locationPayload,
                          'cities_municipalities': location!.city.code,
                          'barangays': location!.barangay.code,
                        }),
                        success: 'Profile saved.',
                      );
                      if (!context.mounted) return;
                      if (saved) {
                        Navigator.pop(context);
                      } else {
                        setState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class MobilePasswordScreen extends StatefulWidget {
  const MobilePasswordScreen({super.key});
  @override
  State<MobilePasswordScreen> createState() => _MobilePasswordScreenState();
}

class _MobilePasswordScreenState extends State<MobilePasswordScreen> {
  final current = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change password')),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: current,
            obscureText: true,
            validator: AccountValidation.requiredName,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: password,
            obscureText: true,
            validator: AccountValidation.password,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: confirm,
            obscureText: true,
            validator: (value) =>
                value == password.text ? null : 'Passwords do not match.',
            decoration: const InputDecoration(labelText: 'Confirm password'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final app = AppScope.of(context);
                    setState(() => saving = true);
                    final saved = await perform(
                      context,
                      () => app.changePassword(current.text, password.text),
                      success: 'Password changed. Please sign in again.',
                    );
                    if (!context.mounted) return;
                    if (saved) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    } else {
                      setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Update password'),
          ),
        ],
      ),
    ),
  );
}

class BuyerDocumentsScreen extends StatefulWidget {
  const BuyerDocumentsScreen({super.key});
  @override
  State<BuyerDocumentsScreen> createState() => _BuyerDocumentsScreenState();
}

class _BuyerDocumentsScreenState extends State<BuyerDocumentsScreen> {
  final shop = TextEditingController();
  final docs = <String, Map<String, String>>{};
  Map<String, dynamic>? review;
  String? error;
  bool loading = true, saving = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AppScope.of(context).account.verification();
      if (mounted) {
        setState(() {
          review = result;
          shop.text = '${result?['shop_name'] ?? ''}';
        });
      }
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    shop.dispose();
    super.dispose();
  }

  Future<void> choose(String kind) async {
    setState(() => saving = true);
    try {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (selected.isEmpty) return;
      final file = selected.single;
      final bytes = await file.readAsBytes();
      final pdf = file.extension?.toLowerCase() == 'pdf';
      if (pdf && bytes.length > 512 * 1024) {
        throw StateError('PDF files must be 512 KB or smaller.');
      }
      final uri = pdf
          ? 'data:application/pdf;base64,${base64Encode(bytes)}'
          : await prepareUploadImage(bytes);
      if (mounted) {
        setState(
          () => docs[kind] = {
            'kind': kind,
            'filename': pdf ? file.name : '$kind.jpg',
            'data_uri': uri,
          },
        );
      }
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> viewDocument(Map doc) async {
    setState(() => saving = true);
    try {
      final file = await AppScope.of(
        context,
      ).account.verificationDocument('${doc['id']}');
      if (!mounted) return;
      final bytes = base64Decode('${file['data_uri']}'.split(',').last);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${file['filename']}'),
          content: SizedBox(
            width: 400,
            child: '${file['mime_type']}'.startsWith('image/')
                ? Image.memory(bytes, fit: BoxFit.contain)
                : const Text(
                    'PDF document. Save a copy to open it in your PDF viewer.',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await perform(dialogContext, () async {
                  await FilePicker.saveFile(
                    fileName: '${file['filename']}',
                    bytes: bytes,
                    mimeType: '${file['mime_type']}',
                  );
                });
              },
              child: const Text('Save document'),
            ),
          ],
        ),
      );
    } catch (failure) {
      if (mounted) setState(() => error = failure.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final canSubmit = review == null || review!['decision'] == 'rejected';
    return Scaffold(
      appBar: AppBar(title: const Text('Buyer documents')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                if (review != null)
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${review!['decision']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (review!['reason'] != null)
                          Text('Reason: ${review!['reason']}'),
                        if ('${review!['notes'] ?? ''}'.isNotEmpty)
                          Text('Review notes: ${review!['notes']}'),
                        const SizedBox(height: 8),
                        Text('Submitted: ${review!['submitted_at']}'),
                        ...((review!['documents'] as List?) ?? []).map(
                          (doc) => TextButton.icon(
                            onPressed: saving
                                ? null
                                : () => viewDocument(doc as Map),
                            icon: const Icon(Icons.description_outlined),
                            label: Text('${doc['kind']}'.replaceAll('_', ' ')),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (canSubmit) ...[
                  TextField(
                    controller: shop,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Shop / business name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Attach all three documents. Images are compressed; PDF limit is 512 KB per file.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  ...{
                    'business_permit': 'Business permit',
                    'valid_id': 'Valid ID',
                    'shop_photo': 'Shop photo',
                  }.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : () => choose(entry.key),
                        icon: Icon(
                          docs.containsKey(entry.key)
                              ? Icons.check_circle
                              : Icons.upload_file,
                        ),
                        label: Text(
                          '${entry.value}${docs[entry.key] == null ? '' : ' · ${docs[entry.key]!['filename']}'}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (shop.text.trim().isEmpty || docs.length != 3) {
                              setState(
                                () => error =
                                    'Enter your shop name and attach all three documents.',
                              );
                              return;
                            }
                            setState(() => saving = true);
                            final saved = await perform(
                              context,
                              () async {
                                await app.account.submitVerification(
                                  shop.text.trim(),
                                  docs.values.toList(),
                                );
                                await app.refresh();
                              },
                              success: 'Documents submitted for LGU review.',
                            );
                            if (!context.mounted) return;
                            setState(() => saving = false);
                            if (saved) await load();
                          },
                    child: Text(
                      saving ? 'Please wait…' : 'Submit for verification',
                    ),
                  ),
                ] else
                  const Text(
                    'Your submitted application is view-only while pending or approved.',
                  ),
                TextButton(
                  onPressed: saving ? null : load,
                  child: const Text('Refresh review status'),
                ),
              ],
            ),
    );
  }
}
