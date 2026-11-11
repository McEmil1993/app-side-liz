import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../application/app_controller.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import 'widgets.dart';
import 'location_fields.dart';
import '../domain/location.dart';
import '../domain/map_location.dart';
import 'maps/address_map.dart';

class PostPickupScreen extends StatelessWidget {
  const PostPickupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('New Pickup Request')),
    body: PostPickupForm(onPublished: () => Navigator.pop(context)),
  );
}

class PostPickupForm extends StatefulWidget {
  final VoidCallback onPublished;
  const PostPickupForm({super.key, required this.onPublished});
  @override
  State<PostPickupForm> createState() => _PostPickupFormState();
}

class _PostPickupFormState extends State<PostPickupForm> {
  final form = GlobalKey<FormState>();
  final weight = TextEditingController();
  final street = TextEditingController(text: 'Purok 1');
  LocationSelection? address;
  LocationOption? chosenCity;
  GeoPin? selectedPin, resolvedPin;
  int addressRevision = 0;
  String mappedStreet = '';
  final notes = TextEditingController();
  final picker = ImagePicker();
  String category = 'Plastic';
  late DateTime date;
  bool dateInitialized = false;
  int hour = 9;
  Uint8List? photo;
  bool picking = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!dateInitialized) {
      final app = AppScope.of(context);
      date = app.now.add(const Duration(days: 1));
      street.text = app.user.streetPurok;
      mappedStreet = street.text.trim();
      selectedPin = app.profilePin;
      dateInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _recoverPhoto();
    }
  }

  Future<void> _recoverPhoto() async {
    try {
      final result = await picker.retrieveLostData();
      if (result.files?.isNotEmpty ?? false) {
        final bytes = await result.files!.first.readAsBytes();
        if (mounted) setState(() => photo = bytes);
      }
    } catch (_) {
      /* A cancelled/lost photo never blocks the request form. */
    }
  }

  Future<void> _pickPhoto() async {
    setState(() => picking = true);
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw StateError('Choose a photo smaller than 5 MB.');
        }
        if (mounted) setState(() => photo = bytes);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photo could not be selected. Check photo access or try a smaller image.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  void dispose() {
    weight.dispose();
    street.dispose();
    notes.dispose();
    super.dispose();
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 18),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
  Future<void> _publish() async {
    if (!form.currentState!.validate()) return;
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your city / municipality and barangay.'),
        ),
      );
      return;
    }
    final app = AppScope.of(context);
    final start = DateTime(date.year, date.month, date.day, hour);
    final request = Pickup(
      id: 'P${DateTime.now().microsecondsSinceEpoch}',
      ownerId: app.user.id,
      ownerName: app.user.name,
      category: category,
      estimatedKg: double.parse(weight.text),
      barangay: address?.barangay.name ?? '',
      cityMunicipality: address!.city.name,
      cityMunicipalityCode: address!.city.code,
      barangayCode: address?.barangay.code ?? '',
      streetPurok: street.text.trim(),
      windowStart: start,
      windowEnd: start.add(const Duration(hours: 3)),
      notes: notes.text.trim(),
      photo: photo,
      locationPin: selectedPin ?? resolvedPin,
    );
    if (await perform(
      context,
      () => app.publish(request),
      success: 'Pickup request published.',
    )) {
      if (!mounted) return;
      weight.clear();
      notes.clear();
      setState(() => photo = null);
      widget.onPublished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.role != UserRole.household) {
      return const EmptyState(
        'Household feature',
        'Switch to the household demo to create a pickup.',
      );
    }
    return Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const SectionTitle('Turn your scrap into value'),
          const Text(
            'Tell nearby buyers what you have ready.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          label('Material category'),
          DropdownButtonFormField<String>(
            key: ValueKey(app.catalog.join('|')),
            initialValue: app.catalog.contains(category) ? category : null,
            validator: (value) =>
                value == null ? 'Choose an active material category.' : null,
            items: app.catalog
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Row(
                      children: [
                        Icon(
                          categoryIcon(item),
                          size: 20,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 12),
                        Text(item),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => category = value!),
          ),
          label('Estimated weight'),
          TextFormField(
            key: const Key('post-estimated-weight'),
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'e.g. 8',
              suffixText: 'kg',
            ),
            validator: (value) {
              final number = double.tryParse(value ?? '');
              return number == null ||
                      !number.isFinite ||
                      number <= 0 ||
                      number > 1000
                  ? 'Enter a weight between 0 and 1,000 kg.'
                  : null;
            },
          ),
          label('Photo (optional)'),
          Row(
            children: [
              if (photo != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        photo!,
                        width: 95,
                        height: 95,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton.filledTonal(
                        onPressed: () => setState(() => photo = null),
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Remove photo',
                        constraints: const BoxConstraints.tightFor(
                          width: 30,
                          height: 30,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              OutlinedButton(
                onPressed: picking ? null : _pickPhoto,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 20,
                  ),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.add_a_photo_outlined),
                    const SizedBox(height: 5),
                    Text(
                      picking
                          ? 'Choosing…'
                          : photo == null
                          ? 'Add photo'
                          : 'Change photo',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          label('Pickup address'),
          BoholLocationFields(
            key: ValueKey('pickup-address-$addressRevision'),
            initialCityCode:
                address?.city.code ?? app.user.cityMunicipalityCode,
            initialBarangayCode:
                address?.barangay.code ?? app.user.barangayCode,
            onCityChanged: (city) => setState(() {
              chosenCity = city;
              selectedPin = null;
              resolvedPin = null;
            }),
            onChanged: (value) => setState(() {
              final changed = address?.barangay.code != value?.barangay.code;
              address = value;
              if (value != null) chosenCity = value.city;
              if (changed) {
                selectedPin =
                    value?.city.code == app.user.cityMunicipalityCode &&
                        value?.barangay.code == app.user.barangayCode
                    ? app.profilePin
                    : null;
              }
              resolvedPin = null;
            }),
          ),
          const SizedBox(height: 12),
          Focus(
            onFocusChange: (focused) {
              if (!focused && mappedStreet != street.text.trim()) {
                setState(() {
                  selectedPin = null;
                  mappedStreet = street.text.trim();
                });
              }
            },
            child: TextFormField(
              controller: street,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Street / Purok',
                counterText: '',
              ),
              validator: (value) =>
                  value!.trim().isEmpty && selectedPin?.location == null
                  ? 'Enter your street or purok, or confirm a map pin.'
                  : null,
            ),
          ),
          if (address != null || chosenCity != null) ...[
            const SizedBox(height: 16),
            AddressMap(
              key: const Key('post-pickup-map'),
              address: MapAddress(
                street: street.text.trim(),
                barangay: address?.barangay.name ?? '',
                city: address?.city.name ?? chosenCity!.name,
                barangayCode: address?.barangay.code ?? '',
              ),
              savedPin: selectedPin,
              onResolved: (pin) => resolvedPin = pin,
              onSave: (pin) => setState(() {
                selectedPin = pin;
                addressRevision++;
                address = pin.location ?? address;
                chosenCity = address?.city ?? chosenCity;
                street.text = pin.street;
                mappedStreet = pin.street;
                resolvedPin = null;
              }),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bohol · Exact address is shared after selection.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          label('Preferred pickup window'),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: constraints.maxWidth > 320
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: app.now,
                        lastDate: app.now.add(const Duration(days: 90)),
                      );
                      if (chosen != null && mounted) {
                        setState(() => date = chosen);
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      dateLabel(date),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth > 320
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth,
                  child: DropdownButtonFormField<int>(
                    initialValue: hour,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 9,
                        child: Text(
                          '9 AM – 12 PM',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 13,
                        child: Text(
                          '1 PM – 4 PM',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => hour = value!),
                  ),
                ),
              ],
            ),
          ),
          label('Pickup notes (optional)'),
          TextFormField(
            controller: notes,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Landmark, material condition, or instructions',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: app.busy ? null : _publish,
            child: Text(app.busy ? 'Publishing…' : 'Publish request'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Final weight and price are agreed in person. No online payment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
