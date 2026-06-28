import 'package:flutter/material.dart';
import '../../widgets/ui_components.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      icon: Icons.camera_alt_rounded,
      title: 'Snap & Report',
      description: 'Capture infrastructure issues with photos and GPS-tagged location in seconds.',
      color: Color(0xFF3B82F6),
    ),
    _OnboardingSlide(
      icon: Icons.psychology_rounded,
      title: 'AI-Powered Verification',
      description: 'Gemini Vision validates each report, filtering spam and auto-categorizing issues.',
      color: Color(0xFF10B981),
    ),
    _OnboardingSlide(
      icon: Icons.map_rounded,
      title: 'Track on the Map',
      description: 'Visualize incidents in real-time. Follow status from report to resolution.',
      color: Color(0xFFF59E0B),
    ),
    _OnboardingSlide(
      icon: Icons.people_rounded,
      title: 'Community Driven',
      description: 'Join citizens and officials working together to fix what matters.',
      color: Color(0xFF8B5CF6),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: widget.onComplete,
                  child: Text('Skip', style: TextStyle(color: theme.colorScheme.primary)),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return FadeSlideIn(
                    delay: Duration(milliseconds: 100 * index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated icon container
                          PulseGlow(
                            glowColor: slide.color,
                            intensity: 0.4,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: slide.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: slide.color.withValues(alpha: 0.3)),
                              ),
                              child: Icon(slide.icon, size: 64, color: slide.color),
                            ),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            slide.title,
                            style: theme.textTheme.displayMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            slide.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? theme.colorScheme.primary : theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // CTA button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_currentPage == _slides.length - 1 ? 'Get Started' : 'Next'),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
