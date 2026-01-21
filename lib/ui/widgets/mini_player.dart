import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/track.dart';
import '../../providers/app_providers.dart';
import '../screens/player_screen.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  // Animation state
  late AnimationController _animController;
  late Animation<double> _offsetAnimation;
  double _dragOffset = 0.0;

  // Track logic state
  bool _isSwipingOut = false;
  String? _lastMediaId;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _offsetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragOffset = _offsetAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isSwipingOut) return;
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _handleDragEnd(DragEndDetails details, AudioHandler handler) {
    if (_isSwipingOut) return;

    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.25; // Swipe 25% to trigger
    final velocity = details.primaryVelocity ?? 0;

    // Swipe Left (Next)
    if (_dragOffset < -threshold || velocity < -500) {
      _animateTo(-width, () {
        _isSwipingOut = true;
        handler.skipToNext();
      });
    }
    // Swipe Right (Previous)
    else if (_dragOffset > threshold || velocity > 500) {
      _animateTo(width, () {
        _isSwipingOut = true;
        handler.skipToPrevious();
      });
    }
    // Spring back
    else {
      _animateTo(0);
    }
  }

  void _animateTo(double target, [VoidCallback? onComplete]) {
    _offsetAnimation = Tween<double>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.reset();
    _animController.forward().then((_) {
      onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final mediaItemAsync = ref.watch(currentMediaItemProvider);
    final playbackStateAsync = ref.watch(playbackStateProvider);

    final mediaItem = mediaItemAsync.value;
    final playing = playbackStateAsync.value?.playing ?? false;
    final processingState = playbackStateAsync.value?.processingState;
    final isLoading =
        processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;

    // --- LISTENER: Handle Incoming Track Animation ---
    ref.listen<AsyncValue<MediaItem?>>(currentMediaItemProvider, (prev, next) {
      final newId = next.value?.id;

      // If the ID changed
      if (newId != _lastMediaId) {
        _lastMediaId = newId;

        // If we were in the middle of a swipe-out action
        if (_isSwipingOut) {
          final width = MediaQuery.of(context).size.width;

          // Determine entry side based on where we left
          // If we swiped LEFT (-width), new song enters from RIGHT (width)
          // If we swiped RIGHT (width), new song enters from LEFT (-width)
          double startPos = _dragOffset < 0 ? width : -width;

          setState(() {
            _dragOffset = startPos;
            _isSwipingOut = false;
          });

          // Animate back to center
          _animateTo(0);
        }
      }
    });

    if (mediaItem == null) return const SizedBox.shrink();

    // Calculate opacity for background icons based on drag
    final double opacity = (_dragOffset.abs() / 100).clamp(0.0, 1.0);
    final bool isSwipeNext = _dragOffset < 0; // Dragging left
    final bool isSwipePrev = _dragOffset > 0; // Dragging right

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: (d) => _handleDragEnd(d, audioHandler),
      onTap: () {
        FocusScope.of(context).unfocus();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const PlayerScreen(),
            transitionsBuilder: (_, animation, _, child) {
              const curve = Curves.easeOutQuart;
              var tween = Tween(begin: const Offset(0.0, 1.0), end: Offset.zero)
                  .chain(CurveTween(curve: curve));
              return SlideTransition(
                  position: animation.drive(tween), child: child);
            },
            opaque: false,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // --- LAYER 1: Background Indicators (Swipe Feedback) ---
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous Icon (Visible when dragging Right)
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0),
                      child: Opacity(
                        opacity: isSwipePrev ? opacity : 0,
                        child: Transform.scale(
                          scale: 0.8 + (opacity * 0.2),
                          child: const Icon(
                            Icons.skip_previous_rounded,
                            color: Color(0xFFFF5252),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    // Next Icon (Visible when dragging Left)
                    Padding(
                      padding: const EdgeInsets.only(right: 24.0),
                      child: Opacity(
                        opacity: isSwipeNext ? opacity : 0,
                        child: Transform.scale(
                          scale: 0.8 + (opacity * 0.2),
                          child: const Icon(
                            Icons.skip_next_rounded,
                            color: Color(0xFFFF5252),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- LAYER 2: Actual Player Content (Slideable) ---
              Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: Container(
                  color: const Color(0xFF2A2A2A), // Matches background to hide icons
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Album Art
                      Hero(
                        tag: 'album_art',
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: (mediaItem.artUri != null)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: mediaItem.artUri.toString(),
                                    httpHeaders: Track.imageHeaders,
                                    fit: BoxFit.cover,
                                    errorWidget: (ctx, _, _) => const Center(
                                      child: Icon(
                                        Icons.music_note_rounded,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.white54,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mediaItem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              mediaItem.artist ?? "Unknown Artist",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Play/Pause Button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF7E5F), Color(0xFFFF5252)],
                          ),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isLoading
                                ? Icons.more_horiz
                                : (playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded),
                            color: Colors.black87,
                            size: 26,
                          ),
                          onPressed: () {
                            if (playing) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- LAYER 3: Progress Bar (Sticky at bottom) ---
              // We keep this outside the Transform so it doesn't slide away
              // unless we want it to. Usually better to slide it with content,
              // but keeping it static looks cleaner during transition.
              Positioned(
                bottom: 0,
                left: 16,
                right: 16,
                child: StreamBuilder<Duration>(
                  stream: AudioService.position,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = mediaItem.duration ?? Duration.zero;
                    double progress = 0.0;
                    if (duration.inMilliseconds > 0) {
                      progress =
                          position.inMilliseconds / duration.inMilliseconds;
                      if (progress > 1.0) progress = 1.0;
                    }
                    // Hide bar if loading or if we are swiping actively
                    if (isLoading || _isSwipingOut) return const SizedBox.shrink();

                    // Animate the bar sliding with the content
                    return Transform.translate(
                      offset: Offset(_dragOffset, 0),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          height: 3,
                          width: (MediaQuery.of(context).size.width - 64) *
                              progress,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}