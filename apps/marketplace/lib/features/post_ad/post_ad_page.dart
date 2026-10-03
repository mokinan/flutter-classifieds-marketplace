import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace/core/providers.dart';
import 'package:marketplace/features/post_ad/post_ad_controller.dart';
import 'package:marketplace/l10n/l10n.dart';
import 'package:marketplace_api/marketplace_api.dart';
import 'package:ui_kit/ui_kit.dart';

class PostAdPage extends ConsumerWidget {
  const PostAdPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(postAdProvider);
    final controller = ref.read(postAdProvider.notifier);

    ref.listen(postAdProvider.select((s) => s.publishError), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.errorTitle(error))));
      }
    });

    if (state.published != null) return _Published(listing: state.published!, onReset: controller.reset);

    final step = state.step;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sellTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: StepProgress(
              current: step.index,
              labels: [l10n.stepPhotos, l10n.stepDetails, l10n.stepPrice, l10n.stepReview],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          switch (step) {
            PostAdStep.photos => _PhotosStep(state: state),
            PostAdStep.details => _DetailsStep(state: state),
            PostAdStep.price => _PriceStep(state: state),
            PostAdStep.review => _ReviewStep(state: state),
          },
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              if (step != PostAdStep.photos) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: controller.back,
                    child: Text(l10n.back),
                  ),
                ),
                const SizedBox(width: Space.md),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('next'),
                  onPressed: state.publishing
                      ? null
                      : (step == PostAdStep.review ? controller.publish : controller.next),
                  child: state.publishing
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Text(step == PostAdStep.review ? l10n.publish : l10n.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _errorText(AppLocalizations l10n, PostAdState state, String field) {
  if (!state.showErrors) return null;
  return switch (state.errorsFor(state.step)[field]) {
    FieldError.required => l10n.errorRequired,
    FieldError.tooShort => l10n.errorTooShort,
    FieldError.invalidPrice => l10n.errorInvalidPrice,
    FieldError.needsPhoto => l10n.errorNeedsPhoto,
    FieldError.uploadsPending => l10n.errorUploadsPending,
    null => null,
  };
}

class _PhotosStep extends ConsumerWidget {
  const _PhotosStep({required this.state});

  final PostAdState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(postAdProvider.notifier);
    final error = _errorText(l10n, state, 'photos');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.photosHint),
        const SizedBox(height: Space.lg),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          children: [
            for (final photo in state.photos) _PhotoTile(photo: photo),
            if (state.photos.length < PostAdState.maxPhotos)
              OutlinedButton(
                key: const Key('add-photos'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                ),
                onPressed: controller.addPhotos,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_a_photo_outlined),
                    const SizedBox(height: Space.xs),
                    Text(l10n.addPhotos, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: Space.md),
          Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({required this.photo});

  final PhotoUpload photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(postAdProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(photo.bytes, fit: BoxFit.cover, cacheWidth: 300),
          if (photo.status != UploadStatus.done)
            ColoredBox(
              color: Colors.black45,
              child: Center(
                child: photo.status == UploadStatus.failed
                    ? IconButton(
                        tooltip: context.l10n.uploadFailed,
                        onPressed: () => controller.retryUpload(photo.localId),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      )
                    : SizedBox.square(
                        dimension: 36,
                        child: CircularProgressIndicator(value: photo.progress, color: Colors.white, strokeWidth: 3),
                      ),
              ),
            ),
          PositionedDirectional(
            top: 2,
            end: 2,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: scheme.surface.withValues(alpha: 0.8)),
              onPressed: () => controller.removePhoto(photo.localId),
              icon: const Icon(Icons.close, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsStep extends ConsumerWidget {
  const _DetailsStep({required this.state});

  final PostAdState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(postAdProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    return Column(
      children: [
        TextFormField(
          key: const Key('title'),
          initialValue: state.title,
          onChanged: controller.titleChanged,
          maxLength: 70,
          decoration: InputDecoration(labelText: l10n.titleLabel, errorText: _errorText(l10n, state, 'title')),
        ),
        const SizedBox(height: Space.sm),
        DropdownButtonFormField<String>(
          initialValue: state.category,
          decoration: InputDecoration(labelText: l10n.categoryLabel, errorText: _errorText(l10n, state, 'category')),
          items: [for (final c in categories) DropdownMenuItem(value: c.slug, child: Text(l10n.categoryName(c.slug)))],
          onChanged: (v) => controller.categoryChanged(v!),
        ),
        const SizedBox(height: Space.lg),
        TextFormField(
          key: const Key('description'),
          initialValue: state.description,
          onChanged: controller.descriptionChanged,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          decoration: InputDecoration(
            labelText: l10n.descriptionLabel,
            alignLabelWithHint: true,
            errorText: _errorText(l10n, state, 'description'),
          ),
        ),
      ],
    );
  }
}

class _PriceStep extends ConsumerWidget {
  const _PriceStep({required this.state});

  final PostAdState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(postAdProvider.notifier);
    return Column(
      children: [
        TextFormField(
          key: const Key('price'),
          initialValue: state.priceText,
          onChanged: controller.priceChanged,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.priceLabel, errorText: _errorText(l10n, state, 'price')),
        ),
        const SizedBox(height: Space.lg),
        DropdownButtonFormField<String>(
          initialValue: state.city,
          decoration: InputDecoration(labelText: l10n.cityLabel, errorText: _errorText(l10n, state, 'city')),
          items: [for (final c in Listing.demoCities) DropdownMenuItem(value: c, child: Text(l10n.cityName(c)))],
          onChanged: (v) => controller.cityChanged(v!),
        ),
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.state});

  final PostAdState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.photos.isNotEmpty)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(state.photos.first.bytes, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PriceText(state.priceHalalas ?? 0, style: theme.textTheme.headlineSmall),
                const SizedBox(height: Space.xs),
                Text(state.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: Space.xs),
                Text(
                  '${l10n.cityName(state.city ?? '')} · ${l10n.categoryName(state.category ?? '')}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Space.md),
                Text(state.description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Published extends StatelessWidget {
  const _Published({required this.listing, required this.onReset});

  final Listing listing;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sellTitle)),
      body: StatusView(
        icon: Icons.check_circle_outline,
        title: l10n.publishedTitle,
        message: listing.title,
        actionLabel: l10n.postAnother,
        onAction: onReset,
      ),
    );
  }
}
