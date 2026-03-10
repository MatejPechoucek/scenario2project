import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IntSpinnerField extends StatefulWidget {
  final String label;
  final int max;
  final ValueChanged<int> onChanged;

  const IntSpinnerField({
    super.key,
    required this.label,
    required this.max,
    required this.onChanged,
  });

  @override
  State<IntSpinnerField> createState() => _IntSpinnerFieldState();
}

class _IntSpinnerFieldState extends State<IntSpinnerField> {
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
