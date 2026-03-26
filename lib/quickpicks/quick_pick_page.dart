import 'dart:async';
import 'package:flutter/material.dart';
import '../services/quickpick_service.dart';
import 'quick_pick_results_page.dart';

/// Full-screen question flow for a Quick Picks session.
///
/// Shows 5 trade-off questions one at a time with two large tappable cards.
/// After answering all 5, shows "waiting for them" or navigates to results.
/// Includes a 60-second countdown timer (decorative — doesn't block answers).
class QuickPickPage extends StatefulWidget {
  final int otherUserId;
  final String? otherUserName;

  const QuickPickPage({
    super.key,
    required this.otherUserId,
    this.otherUserName,
  });

  @override
  State<QuickPickPage> createState() => _QuickPickPageState();
}

class _QuickPickPageState extends State<QuickPickPage> {
  bool _loading = true;
  String? _error;

  int? _sessionId;
  String _status = '';
  List<dynamic> _questions = [];
  Map<String, dynamic> _myAnswers = {}; // question_index (as string) → option
  int _currentIndex = 0;
  bool _submitting = false;
  bool _navigatedToResults = false;

  // Countdown timer (decorative, 60s total)
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  Future<void> _loadSession() async {
    try {
      final data = await QuickPickService.getSession(widget.otherUserId);
      if (!mounted) return;
      setState(() {
        _sessionId = data['session_id'] as int?;
        _status = data['status'] as String? ?? '';
        _questions = data['questions'] as List<dynamic>? ?? [];
        final answers = data['my_answers'] as Map<String, dynamic>? ?? {};
        _myAnswers = answers;
        // Jump to first unanswered question
        _currentIndex = answers.length;
        if (_currentIndex >= _questions.length) {
          _currentIndex = _questions.length - 1;
        }
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectOption(String option) async {
    if (_submitting || _sessionId == null) return;
    setState(() => _submitting = true);

    try {
      await QuickPickService.submitAnswer(
        sessionId: _sessionId!,
        questionIndex: _currentIndex,
        selectedOption: option,
      );

      if (!mounted) return;

      setState(() {
        _myAnswers['$_currentIndex'] = option;
        _submitting = false;
      });

      // Check if all questions answered
      if (_myAnswers.length >= _questions.length) {
        _timer?.cancel();
        // Re-fetch session to get updated status
        final data = await QuickPickService.getSession(widget.otherUserId);
        if (!mounted) return;
        final status = data['status'] as String? ?? '';

        if (status == 'completed') {
          _navigateToResults();
        } else {
          setState(() => _status = status);
        }
      } else {
        setState(() => _currentIndex = _myAnswers.length);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _navigateToResults() {
    if (_sessionId == null || _navigatedToResults) return;
    _navigatedToResults = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuickPickResultsPage(
          sessionId: _sessionId!,
          otherUserName: widget.otherUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    final brandLight = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quick Picks with ${widget.otherUserName ?? 'them'}'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(brand, brandLight),
    );
  }

  Widget _buildContent(Color brand, Color brandLight) {
    // All answered — waiting state
    if (_myAnswers.length >= _questions.length) {
      return _buildWaitingState(brand, brandLight);
    }

    if (_questions.isEmpty) {
      return const Center(child: Text('No questions available'));
    }

    final q = _questions[_currentIndex] as Map<String, dynamic>;
    final prompt = q['prompt'] as String? ?? '';
    final optionA = q['option_a'] as String? ?? 'A';
    final optionB = q['option_b'] as String? ?? 'B';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progress + timer row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1} / ${_questions.length}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: brand,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _secondsLeft <= 10
                      ? Colors.red.withValues(alpha: 0.1)
                      : brandLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_secondsLeft}s',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _secondsLeft <= 10 ? Colors.red : brand,
                  ),
                ),
              ),
            ],
          ),

          // Progress bar
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: brandLight.withValues(alpha: 0.2),
              color: brand,
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 40),

          // Question prompt
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),

          const Spacer(),

          // Option A
          _buildOptionCard(
            label: optionA,
            option: 'a',
            brand: brand,
            brandLight: brandLight,
          ),

          const SizedBox(height: 16),

          // "or" divider
          Text(
            'or',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 16),

          // Option B
          _buildOptionCard(
            label: optionB,
            option: 'b',
            brand: brand,
            brandLight: brandLight,
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String label,
    required String option,
    required Color brand,
    required Color brandLight,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _submitting ? null : () => _selectOption(option),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: brandLight, width: 2),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: brand,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingState(Color brand, Color brandLight) {
    // Check if session completed while we're on this screen
    if (_status == 'completed') {
      // Auto-navigate to results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToResults();
      });
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 64, color: brand),
            const SizedBox(height: 20),
            const Text(
              "You're done!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              "Waiting for ${widget.otherUserName ?? 'them'} to finish their answers...",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                // Poll for completion
                try {
                  final data = await QuickPickService.getSession(widget.otherUserId);
                  if (!mounted) return;
                  final status = data['status'] as String? ?? '';
                  if (status == 'completed') {
                    _navigateToResults();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Still waiting...')),
                    );
                  }
                } catch (_) {}
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Check again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: brand,
                side: BorderSide(color: brandLight),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Back to matches',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
