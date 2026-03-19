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

class _IntSpinnerFieldState extends State<IntSpinnerField>
    with WidgetsBindingObserver {
  final _controller = TextEditingController(text: '0');
  final _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeMetrics() {
    // Rebuild overlay when keyboard animates in/out so it repositions correctly.
    _overlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideDoneButton();
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showDoneButton();
    } else {
      _hideDoneButton();
    }
  }

  void _showDoneButton() {
    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Positioned(
          bottom: bottom,
          left: 0,
          right: 0,
          child: Material(
            elevation: 0,
            child: Container(
              height: 44,
              color: const Color(0xFFD1D5DB),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _focusNode.unfocus(),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDoneButton() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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

  void _onTextChanged(String text) {
    final val = (int.tryParse(text) ?? 0).clamp(0, widget.max);
    final clamped = val.toString();
    if (clamped != text) {
      _controller.value = TextEditingValue(
        text: clamped,
        selection: TextSelection.collapsed(offset: clamped.length),
      );
    }
    widget.onChanged(val);
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
          focusNode: _focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: const TextStyle(fontSize: 10),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
