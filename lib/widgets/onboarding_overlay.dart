// lib/widgets/onboarding_overlay.dart
// يظهر مرة واحدة فقط عند أول استخدام — قابل للسحب + أزرار تالي/سابق/إنهاء

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStep {
  final String   title;
  final String   description;
  final IconData icon;
  const OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class OnboardingOverlay extends StatefulWidget {
  final String               tutorialKey;
  final List<OnboardingStep> steps;
  final Widget               child;

  const OnboardingOverlay({
    super.key,
    required this.tutorialKey,
    required this.steps,
    required this.child,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {

  bool _show = false;
  late final PageController _pageCtrl;
  late AnimationController  _fadeCtrl;
  late Animation<double>    _fadeAnim;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _checkSeen();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSeen() async {
    if (widget.steps.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final seen  = prefs.getBool('ob_${widget.tutorialKey}') ?? false;
    if (!seen && mounted) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() { _show = true; _current = 0; });
      _fadeCtrl.forward();
    }
  }

  Future<void> _dismiss() async {
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() => _show = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ob_${widget.tutorialKey}', true);
  }

  void _goTo(int i) {
    setState(() => _current = i);
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_show)
        FadeTransition(
          opacity: _fadeAnim,
          child: _OnboardingSheet(
            steps:    widget.steps,
            current:  _current,
            ctrl:     _pageCtrl,
            onPageChanged: (i) => setState(() => _current = i),
            onNext:   _current < widget.steps.length - 1
                          ? () => _goTo(_current + 1)
                          : _dismiss,
            onPrev:   _current > 0 ? () => _goTo(_current - 1) : null,
            onSkip:   _dismiss,
          ),
        ),
    ]);
  }
}

// ── الـ Sheet الشفاف ──────────────────────────────────────────────────────────
class _OnboardingSheet extends StatelessWidget {
  final List<OnboardingStep> steps;
  final int            current;
  final PageController ctrl;
  final ValueChanged<int> onPageChanged;
  final VoidCallback   onNext;
  final VoidCallback?  onPrev;
  final VoidCallback   onSkip;

  const _OnboardingSheet({
    required this.steps,
    required this.current,
    required this.ctrl,
    required this.onPageChanged,
    required this.onNext,
    required this.onPrev,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = current == steps.length - 1;

    return Container(
      // ── لون أزرق/سماوي شفاف كما طلب ──────────────────────────────────
      color: const Color(0xFF0D47A1).withValues(alpha: 0.82),
      child: SafeArea(
        child: Column(children: [
          // ── زر تخطي ────────────────────────────────────────────────────
          Align(
            alignment: Alignment.topLeft,
            child: TextButton(
              onPressed: onSkip,
              child: const Text('تخطي',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ),

          // ── PageView قابل للسحب ─────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller:    ctrl,
              onPageChanged: onPageChanged,
              itemCount:     steps.length,
              itemBuilder:   (_, i) => _StepPage(step: steps[i]),
            ),
          ),

          // ── نقاط التقدم ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(steps.length, (i) {
              final active = i == current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width:  active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // ── أزرار التنقل ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              // السابق
              if (onPrev != null)
                OutlinedButton(
                  onPressed: onPrev,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('السابق'),
                )
              else
                const SizedBox(width: 90),

              const Spacer(),

              // التالي / إنهاء
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D47A1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  isLast ? 'ابدأ الآن 🎉' : 'التالي ←',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── صفحة خطوة واحدة ───────────────────────────────────────────────────────────
class _StepPage extends StatelessWidget {
  final OnboardingStep step;
  const _StepPage({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // أيقونة دائرية
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
              boxShadow: [
                BoxShadow(
                  color:      Colors.white.withValues(alpha: 0.1),
                  blurRadius: 20, spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(step.icon, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 32),

          // العنوان
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24, fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),

          // الوصف
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 15, height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
