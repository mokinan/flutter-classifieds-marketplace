import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace/features/post_ad/photo_services.dart';
import 'package:marketplace/features/post_ad/post_ad_controller.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

class _FakePhotos implements PhotoSource {
  _FakePhotos(this.count);
  final int count;

  @override
  Future<List<Uint8List>> pick({required int max}) async =>
      List.generate(count < max ? count : max, (i) => Uint8List.fromList(List.filled(100, i)));
}

/// "Compresses" by halving, so tests can see compression happened.
class _HalvingCompressor implements ImageCompressor {
  @override
  Future<Uint8List> compress(Uint8List bytes) async => Uint8List.sublistView(bytes, 0, bytes.length ~/ 2);
}

void main() {
  late MockApi api;
  late SimulatedImageUploader uploader;

  setUpAll(registerFallbacks);

  setUp(() {
    api = MockApi();
    uploader = SimulatedImageUploader(chunkDelay: Duration.zero);
    when(() => api.uploadImage(any(), onProgress: any(named: 'onProgress'))).thenAnswer(
      (i) => uploader.upload(
        i.positionalArguments.first as List<int>,
        onProgress: i.namedArguments[#onProgress] as void Function(double)?,
      ),
    );
  });

  Future<PostAdController> controllerWith({int photos = 2, Map<String, Object> prefs = const {}}) async {
    final container = await makeContainer(
      api: api,
      prefs: prefs,
      overrides: [
        photoSourceProvider.overrideWithValue(_FakePhotos(photos)),
        imageCompressorProvider.overrideWithValue(_HalvingCompressor()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(postAdProvider, (_, _) {});
    return container.read(postAdProvider.notifier);
  }

  test('requires a photo, then waits for uploads to finish', () async {
    final controller = await controllerWith();
    expect(controller.next(), isFalse);
    expect(controller.state.errorsFor(PostAdStep.photos), {'photos': FieldError.needsPhoto});

    await controller.addPhotos();
    expect(controller.state.photos.first.bytes, hasLength(50), reason: 'compressed before upload');
    await settle();

    expect(controller.state.photos.every((p) => p.status == UploadStatus.done), isTrue);
    expect(controller.next(), isTrue);
    expect(controller.state.step, PostAdStep.details);
  });

  test('a failed upload can be retried on its own', () async {
    uploader.failureRate = 1;
    final controller = await controllerWith(photos: 1);
    await controller.addPhotos();
    await settle();
    final photo = controller.state.photos.single;
    expect(photo.status, UploadStatus.failed);
    expect(controller.state.errorsFor(PostAdStep.photos), {'photos': FieldError.uploadsPending});

    uploader.failureRate = 0;
    await controller.retryUpload(photo.localId);
    expect(controller.state.photos.single.status, UploadStatus.done);
    expect(controller.state.photos.single.remoteId, isNotNull);
  });

  test('validates details and price', () async {
    final controller = await controllerWith(photos: 1);
    await controller.addPhotos();
    await settle();
    controller
      ..next()
      ..titleChanged('Car');
    expect(controller.next(), isFalse);
    expect(controller.state.errorsFor(PostAdStep.details), {
      'title': FieldError.tooShort,
      'category': FieldError.required,
      'description': FieldError.tooShort,
    });

    controller
      ..titleChanged('Toyota Camry 2020')
      ..categoryChanged('vehicle')
      ..descriptionChanged('One owner, full service history.');
    expect(controller.next(), isTrue);

    controller.priceChanged('0');
    expect(controller.next(), isFalse);
    controller
      ..priceChanged('68,500')
      ..cityChanged('Jeddah');
    expect(controller.state.priceHalalas, 6850000);
    expect(controller.next(), isTrue);
    expect(controller.state.step, PostAdStep.review);
  });

  test('saves a draft and restores it', () async {
    final controller = await controllerWith();
    controller
      ..titleChanged('iPhone 15 Pro')
      ..priceChanged('3200');
    await settle(const Duration(milliseconds: 600));

    final raw = (await SharedPreferences.getInstance()).getString('post_ad_draft_v1')!;
    final restored = await controllerWith(prefs: {'post_ad_draft_v1': raw});
    expect(restored.state.title, 'iPhone 15 Pro');
    expect(restored.state.priceText, '3200');
  });

  test('publishing sends uploaded image ids and clears the draft', () async {
    when(() => api.publish(any())).thenAnswer((i) async {
      final draft = i.positionalArguments.first as ListingDraft;
      return listing(99).copyWithDraft(draft);
    });
    final controller = await controllerWith(prefs: {'post_ad_draft_v1': '{"title":"x"}'});
    await controller.addPhotos();
    await settle();
    controller
      ..titleChanged('Gaming laptop')
      ..categoryChanged('laptops')
      ..descriptionChanged('RTX 4070, 32 GB RAM, like new.')
      ..priceChanged('5500')
      ..cityChanged('Riyadh');

    await controller.publish();

    final draft = verify(() => api.publish(captureAny())).captured.single as ListingDraft;
    expect(draft.imageIds, hasLength(2));
    expect(draft.priceHalalas, 550000);
    expect(controller.state.published, isNotNull);
    expect((await SharedPreferences.getInstance()).getString('post_ad_draft_v1'), isNull);
  });

  test('publishing an incomplete ad jumps to the first invalid step', () async {
    final controller = await controllerWith(photos: 1);
    await controller.addPhotos();
    await settle();
    controller.titleChanged('Desk');

    await controller.publish();

    expect(controller.state.step, PostAdStep.details);
    expect(controller.state.showErrors, isTrue);
    verifyNever(() => api.publish(any()));
  });

  test('a publish failure is surfaced and the form is kept', () async {
    when(() => api.publish(any())).thenThrow(const NetworkUnavailable('offline'));
    final controller = await controllerWith(photos: 1);
    await controller.addPhotos();
    await settle();
    controller
      ..titleChanged('Standing desk')
      ..categoryChanged('furniture')
      ..descriptionChanged('Electric, 160 x 80 cm, memory presets.')
      ..priceChanged('900')
      ..cityChanged('Dammam');

    await controller.publish();

    expect(controller.state.publishError, isA<NetworkUnavailable>());
    expect(controller.state.publishing, isFalse);
    expect(controller.state.title, 'Standing desk');
  });
}

extension on Listing {
  Listing copyWithDraft(ListingDraft d) => Listing(
    id: id,
    title: d.title,
    description: d.description,
    priceHalalas: d.priceHalalas,
    category: d.category,
    city: d.city,
    sellerName: 'You',
    thumbnailUrl: '',
    imageUrls: d.imageIds,
    postedAt: postedAt,
  );
}
