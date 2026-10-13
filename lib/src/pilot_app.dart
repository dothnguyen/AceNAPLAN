import 'package:flutter/material.dart';

const _cream = Color(0xFFFFFBF2);
const _navy = Color(0xFF1F2A44);
const _muted = Color(0xFF5A6178);
const _blue = Color(0xFF1D6FD1);
const _amber = Color(0xFFB45309);

class PilotApp extends StatelessWidget {
  const PilotApp({super.key, required this.testMode});

  final bool testMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ace NAPLAN Practice',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _cream,
          colorScheme: ColorScheme.fromSeed(seedColor: _blue, surface: _cream),
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: _navy,
                displayColor: _navy,
              ),
        ),
        home: PilotHome(testMode: testMode),
      );
}

class PilotHome extends StatelessWidget {
  const PilotHome({super.key, required this.testMode});

  final bool testMode;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (testMode) const _TestModeBanner(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: wide ? 40 : 20,
                        vertical: wide ? 40 : 24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _Header(),
                              const SizedBox(height: 36),
                              Text(
                                'A little practice, a lot of learning.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'For Year 4 and early Year 5 learners, with explanations to help children understand their mistakes.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(color: _muted),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Practice areas',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 16),
                              if (wide)
                                const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _SubjectCard(
                                        title: 'Numeracy',
                                        description:
                                            'Maths practice with clear explanations.',
                                        accent: _blue,
                                        icon: Icons.calculate_outlined,
                                      ),
                                    ),
                                    SizedBox(width: 20),
                                    Expanded(
                                      child: _SubjectCard(
                                        title: 'Conventions of Language',
                                        description:
                                            'Spelling, grammar and punctuation practice.',
                                        accent: _amber,
                                        icon: Icons.menu_book_outlined,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                const Column(
                                  children: [
                                    _SubjectCard(
                                      title: 'Numeracy',
                                      description:
                                          'Maths practice with clear explanations.',
                                      accent: _blue,
                                      icon: Icons.calculate_outlined,
                                    ),
                                    SizedBox(height: 16),
                                    _SubjectCard(
                                      title: 'Conventions of Language',
                                      description:
                                          'Spelling, grammar and punctuation practice.',
                                      accent: _amber,
                                      icon: Icons.menu_book_outlined,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 24),
                              const _AvailabilityNote(),
                              const SizedBox(height: 36),
                              Text(
                                'Ace NAPLAN Practice is an independent learning product and is not affiliated with or endorsed by ACARA.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: _muted),
                              ),
                            ],
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
      );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.auto_stories_rounded, color: _blue, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ace NAPLAN Practice',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
}

class _TestModeBanner extends StatelessWidget {
  const _TestModeBanner();

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: _navy,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: const Text(
            'Test mode — progress resets on refresh',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.title,
    required this.description,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String description;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 32),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _muted),
            ),
          ],
        ),
      );
}

class _AvailabilityNote extends StatelessWidget {
  const _AvailabilityNote();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5FB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: _navy),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Practice questions are being prepared. There is no progress to show yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
}
