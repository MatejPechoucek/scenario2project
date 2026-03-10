import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  static const List<String> _meals = [
    'Healthy Gain',
    'Manage Deficiency',
    'Muscle Gain',
    'Custom',
  ];

  static const List<String> _calculator = [
    'Height (CM)',
    'Weight',
    'Age',
    'Activity Level',
  ];

  static const List<int> _calculatorMax = [
    300,  // Height (CM)
    500,  // Weight (KG)
    120,  // Age
    5,    // Activity Level
  ];

  final List<int> _values = [0, 0, 0, 0];

  double _activityMultiplier(int level) {
    switch (level) {
      case 0: return 1;
      case 1: return 1.2;
      case 2: return 1.375;
      case 3: return 1.55;
      case 4: return 1.725;
      case 5: return 1.9;
      default: return 1;
    }
  }

  int _calculateCalories() {
    final height = _values[0];
    final weight = _values[1];
    final age = _values[2];
    final activity = _values[3];
    if (height == 0 || weight == 0 || age == 0) return 0;
    // Mifflin-St Jeor (gender-neutral average)
    final bmr = 10 * weight + 6.25 * height - 5 * age - 78;
    return (bmr * _activityMultiplier(activity)).round();
  }

  @override
  Widget build(BuildContext context) {
    final calories = _calculateCalories();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diet Plan',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 60,
            ),
            itemCount: _meals.length,
            itemBuilder: (context, index) {
              return Card(
                child: Center(
                  child: Text(
                    _meals[index],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 150,
            ),
            itemCount: _calculator.length,
            itemBuilder: (context, index) {
              return _IntSpinnerField(
                label: _calculator[index],
                max: _calculatorMax[index],
                onChanged: (val) => setState(() => _values[index] = val),
              );
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  calories > 0 ? 'Your TDEE is: $calories calories' : 'Your TDEE is: —',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntSpinnerField extends StatefulWidget {
  final String label;
  final int max;
  final ValueChanged<int> onChanged;

  const _IntSpinnerField({required this.label, required this.max, required this.onChanged});

  @override
  State<_IntSpinnerField> createState() => _IntSpinnerFieldState();
}

class _IntSpinnerFieldState extends State<_IntSpinnerField> {
  final _controller = TextEditingController(text: '0');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    final val = int.tryParse(_controller.text) ?? 0;
    if (val < widget.max) {
      _controller.text = (val + 1).toString();
      widget.onChanged(val + 1);
    }
  }

  void _decrement() {
    final val = int.tryParse(_controller.text) ?? 0;
    if (val > 0) {
      _controller.text = (val - 1).toString();
      widget.onChanged(val - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_drop_up),
          onPressed: _increment,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onChanged: (text) {
            final val = int.tryParse(text) ?? 0;
            widget.onChanged(val.clamp(0, widget.max));
          },
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: const TextStyle(fontSize: 10),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_drop_down),
          onPressed: _decrement,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
