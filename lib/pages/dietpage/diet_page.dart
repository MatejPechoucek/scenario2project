import 'package:flutter/material.dart';

import '../../widgets/int_spinner_field.dart';
import 'calorie_calculator.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}


class _DietPageState extends State<DietPage> {
  static const _meals = [
    'Healthy Gain',
    'Manage Deficiency',
    'Muscle Gain',
    'Custom',
  ];

  static const _calculatorFields = [
    (label: 'Height (CM)', max: 300),
    (label: 'Weight (KG)', max: 500),
    (label: 'Age',         max: 120),
    (label: 'Activity',    max: 5),
  ];

  final List<int> _values = [0, 0, 0, 0];

  int get _calories => CalorieCalculator.calculate(
    heightCm:      _values[0],
    weightKg:      _values[1],
    age:           _values[2],
    activityLevel: _values[3],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diet Plan', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          _MealGrid(meals: _meals),
          const SizedBox(height: 16),
          _CalculatorGrid(
            fields: _calculatorFields,
            onChanged: (index, val) => setState(() => _values[index] = val),
          ),
          const SizedBox(height: 8),
          _CalorieCard(calories: _calories),
          _TargetSliders(),
        ],
      ),
    );
  }
}

class _MealGrid extends StatelessWidget {
  final List<String> meals;
  const _MealGrid({required this.meals});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 60,
      ),
      itemCount: meals.length,
      itemBuilder: (context, index) => Card(
        child: Center(
          child: Text(meals[index], style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}

class _CalculatorGrid extends StatelessWidget {
  final List<({String label, int max})> fields;
  final void Function(int index, int value) onChanged;
  const _CalculatorGrid({required this.fields, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 150,
      ),
      itemCount: fields.length,
      itemBuilder: (context, index) => IntSpinnerField(
        label: fields[index].label,
        max: fields[index].max,
        onChanged: (val) => onChanged(index, val),
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final int calories;
  const _CalorieCard({required this.calories});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            calories > 0 ? 'Your TDEE is: $calories calories' : 'Your TDEE is: —',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}


class _TargetSliders extends StatefulWidget {
  const _TargetSliders();

  @override
  State<_TargetSliders> createState() => _TargetSlidersState();
}

class _TargetSlidersState extends State<_TargetSliders> {
  final List<double> _macros = [0, 0, 0];
  static const _macroNames = [
    'Protein',
    'Fat',
    'Carbs',
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 100,
      ),
      itemCount: 3,
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_macroNames[index], style: Theme.of(context).textTheme.headlineSmall),
          Slider(
            value: _macros[index],
            label: _macroNames[index],
            max: 100,
            onChanged: (val) => setState(() => _macros[index] = val),
          ),
        ]
      )
    );
  }
}