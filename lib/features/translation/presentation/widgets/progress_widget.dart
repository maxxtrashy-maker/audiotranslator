import 'package:flutter/material.dart';
import '../providers/translation_provider.dart';

class ProgressWidget extends StatelessWidget {
  final double progress;
  final PipelineStep? currentStep;

  const ProgressWidget({
    super.key,
    required this.progress,
    this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (currentStep != null && _isPipelineMode(currentStep!)) ...[
          const SizedBox(height: 8),
          _buildPipelineIndicator(context),
          const SizedBox(height: 16),
        ],
        const Text("Traitement en cours..."),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 5),
        Text("${(progress * 100).toInt()}%"),
      ],
    );
  }

  bool _isPipelineMode(PipelineStep step) {
    return step == PipelineStep.transcribing ||
        step == PipelineStep.translating ||
        (step == PipelineStep.generatingAudio && currentStep != null);
  }

  Widget _buildPipelineIndicator(BuildContext context) {
    const steps = [
      _StepInfo('Transcription', PipelineStep.transcribing),
      _StepInfo('Traduction', PipelineStep.translating),
      _StepInfo('Synth\u00e8se', PipelineStep.generatingAudio),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Container(
              width: 24,
              height: 2,
              color: _isStepDone(steps[i].step) || _isStepActive(steps[i].step)
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
            ),
          _buildStepDot(context, steps[i]),
        ],
      ],
    );
  }

  Widget _buildStepDot(BuildContext context, _StepInfo info) {
    final done = _isStepDone(info.step);
    final active = _isStepActive(info.step);

    Color color;
    if (done) {
      color = Colors.green;
    } else if (active) {
      color = Theme.of(context).colorScheme.primary;
    } else {
      color = Colors.grey.shade300;
    }

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: done
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : active
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          info.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: done || active ? null : Colors.grey,
          ),
        ),
      ],
    );
  }

  bool _isStepDone(PipelineStep step) {
    if (currentStep == null) return false;
    const order = [
      PipelineStep.transcribing,
      PipelineStep.translating,
      PipelineStep.generatingAudio,
    ];
    final currentIdx = order.indexOf(currentStep!);
    final stepIdx = order.indexOf(step);
    if (currentIdx == -1 || stepIdx == -1) return false;
    return stepIdx < currentIdx;
  }

  bool _isStepActive(PipelineStep step) {
    return currentStep == step;
  }
}

class _StepInfo {
  final String label;
  final PipelineStep step;
  const _StepInfo(this.label, this.step);
}
