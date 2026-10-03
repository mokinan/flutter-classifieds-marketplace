import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/features/post_ad/photo_services.dart';
import 'package:marketplace_api/marketplace_api.dart';

enum UploadStatus { uploading, done, failed }

@immutable
class PhotoUpload {
  const PhotoUpload({
    required this.localId,
    required this.bytes,
    this.progress = 0,
    this.status = UploadStatus.uploading,
    this.remoteId,
  });

  final int localId;

  /// Compressed bytes, kept so a failed upload can be retried.
  final Uint8List bytes;
  final double progress;
  final UploadStatus status;
  final String? remoteId;

  PhotoUpload copyWith({double? progress, UploadStatus? status, String? remoteId}) => PhotoUpload(
    localId: localId,
    bytes: bytes,
    progress: progress ?? this.progress,
    status: status ?? this.status,
    remoteId: remoteId ?? this.remoteId,
  );
}

enum PostAdStep { photos, details, price, review }

enum FieldError { required, tooShort, invalidPrice, needsPhoto, uploadsPending }

@immutable
class PostAdState {
  const PostAdState({
    this.step = PostAdStep.photos,
    this.photos = const [],
    this.title = '',
    this.description = '',
    this.priceText = '',
    this.category,
    this.city,
    this.showErrors = false,
    this.publishing = false,
    this.published,
    this.publishError,
  });

  static const maxPhotos = 6;

  final PostAdStep step;
  final List<PhotoUpload> photos;
  final String title;
  final String description;
  final String priceText;
  final String? category;
  final String? city;
  final bool showErrors;
  final bool publishing;
  final Listing? published;
  final ApiException? publishError;

  /// Whole riyals only; classifieds rarely use decimals.
  int? get priceHalalas {
    final value = int.tryParse(priceText.replaceAll(RegExp(r'[,\s]'), ''));
    return value != null && value > 0 && value < 100000000 ? value * 100 : null;
  }

  /// Errors for the fields of [step], keyed by field name.
  Map<String, FieldError> errorsFor(PostAdStep step) => switch (step) {
    PostAdStep.photos => {
      if (photos.isEmpty) 'photos': FieldError.needsPhoto,
      if (photos.any((p) => p.status != UploadStatus.done)) 'photos': FieldError.uploadsPending,
    },
    PostAdStep.details => {
      if (title.trim().isEmpty)
        'title': FieldError.required
      else if (title.trim().length < 5)
        'title': FieldError.tooShort,
      if (category == null) 'category': FieldError.required,
      if (description.trim().length < 10) 'description': FieldError.tooShort,
    },
    PostAdStep.price => {
      if (priceHalalas == null) 'price': FieldError.invalidPrice,
      if (city == null) 'city': FieldError.required,
    },
    PostAdStep.review => const {},
  };

  PostAdState copyWith({
    PostAdStep? step,
    List<PhotoUpload>? photos,
    String? title,
    String? description,
    String? priceText,
    String? category,
    String? city,
    bool? showErrors,
    bool? publishing,
    Listing? Function()? published,
    ApiException? Function()? publishError,
  }) => PostAdState(
    step: step ?? this.step,
    photos: photos ?? this.photos,
    title: title ?? this.title,
    description: description ?? this.description,
    priceText: priceText ?? this.priceText,
    category: category ?? this.category,
    city: city ?? this.city,
    showErrors: showErrors ?? this.showErrors,
    publishing: publishing ?? this.publishing,
    published: published != null ? published() : this.published,
    publishError: publishError != null ? publishError() : this.publishError,
  );
}

/// Multi-step "post an ad" flow.
///
/// * Photos are compressed, then uploaded in the background with progress;
///   a failed upload keeps its bytes and can be retried individually.
/// * Text fields are saved as a draft, so leaving the screen (or the app
///   being killed) does not lose the user's typing.
class PostAdController extends Notifier<PostAdState> {
  static const _draftKey = 'post_ad_draft_v1';

  int _nextLocalId = 0;
  Timer? _saveTimer;

  @override
  PostAdState build() {
    ref.onDispose(() => _saveTimer?.cancel());
    final raw = ref.watch(sharedPreferencesProvider).getString(_draftKey);
    if (raw == null) return const PostAdState();
    final json = jsonDecode(raw) as Map<String, Object?>;
    return PostAdState(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceText: json['price'] as String? ?? '',
      category: json['category'] as String?,
      city: json['city'] as String?,
    );
  }

  Future<void> addPhotos() async {
    final room = PostAdState.maxPhotos - state.photos.length;
    if (room <= 0) return;
    final picked = await ref.read(photoSourceProvider).pick(max: room);
    final compressor = ref.read(imageCompressorProvider);
    for (final original in picked) {
      final bytes = await compressor.compress(original);
      if (!ref.mounted) return;
      final photo = PhotoUpload(localId: _nextLocalId++, bytes: bytes);
      state = state.copyWith(photos: [...state.photos, photo]);
      unawaited(_upload(photo.localId));
    }
  }

  Future<void> retryUpload(int localId) => _upload(localId);

  void removePhoto(int localId) =>
      state = state.copyWith(photos: state.photos.where((p) => p.localId != localId).toList());

  void titleChanged(String value) => _edit(state.copyWith(title: value));
  void descriptionChanged(String value) => _edit(state.copyWith(description: value));
  void priceChanged(String value) => _edit(state.copyWith(priceText: value));
  void categoryChanged(String value) => _edit(state.copyWith(category: value));
  void cityChanged(String value) => _edit(state.copyWith(city: value));

  /// Advances if the current step is valid; otherwise reveals its errors.
  bool next() {
    if (state.errorsFor(state.step).isNotEmpty) {
      state = state.copyWith(showErrors: true);
      return false;
    }
    state = state.copyWith(step: PostAdStep.values[state.step.index + 1], showErrors: false);
    return true;
  }

  void back() {
    if (state.step.index > 0) state = state.copyWith(step: PostAdStep.values[state.step.index - 1], showErrors: false);
  }

  Future<void> publish() async {
    if (state.publishing) return;
    // Guard against publishing an incomplete ad (e.g. a photo removed after
    // review): send the user to the first step that needs attention.
    final invalid = PostAdStep.values.where((s) => state.errorsFor(s).isNotEmpty).firstOrNull;
    if (invalid != null) {
      state = state.copyWith(step: invalid, showErrors: true);
      return;
    }
    state = state.copyWith(publishing: true, publishError: () => null);
    try {
      final listing = await ref
          .read(marketplaceApiProvider)
          .publish(
            ListingDraft(
              title: state.title.trim(),
              description: state.description.trim(),
              priceHalalas: state.priceHalalas!,
              category: state.category!,
              city: state.city!,
              imageIds: [for (final p in state.photos) p.remoteId!],
            ),
          );
      await ref.read(sharedPreferencesProvider).remove(_draftKey);
      if (ref.mounted) state = state.copyWith(publishing: false, published: () => listing);
    } on ApiException catch (e) {
      if (ref.mounted) state = state.copyWith(publishing: false, publishError: () => e);
    }
  }

  /// Starts a fresh ad after a successful publish.
  void reset() => state = const PostAdState();

  Future<void> _upload(int localId) async {
    PhotoUpload? find() => state.photos.where((p) => p.localId == localId).firstOrNull;
    void update(PhotoUpload Function(PhotoUpload) change) {
      if (!ref.mounted) return;
      state = state.copyWith(photos: [for (final p in state.photos) p.localId == localId ? change(p) : p]);
    }

    final photo = find();
    if (photo == null) return;
    update((p) => p.copyWith(status: UploadStatus.uploading, progress: 0));
    try {
      final remoteId = await ref
          .read(marketplaceApiProvider)
          .uploadImage(photo.bytes, onProgress: (v) => update((p) => p.copyWith(progress: v)));
      update((p) => p.copyWith(status: UploadStatus.done, remoteId: remoteId, progress: 1));
    } on ApiException {
      update((p) => p.copyWith(status: UploadStatus.failed));
    }
  }

  void _edit(PostAdState next) {
    state = next;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveDraft);
  }

  Future<void> _saveDraft() => ref
      .read(sharedPreferencesProvider)
      .setString(
        _draftKey,
        jsonEncode({
          'title': state.title,
          'description': state.description,
          'price': state.priceText,
          'category': state.category,
          'city': state.city,
        }),
      );
}

final postAdProvider = NotifierProvider<PostAdController, PostAdState>(PostAdController.new);
