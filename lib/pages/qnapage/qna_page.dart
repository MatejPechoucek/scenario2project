import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// The barcode scanner doesn't work on Windows/IOS/Linux
class BarcodeScannerPage extends StatelessWidget {
  const BarcodeScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: MobileScanner(
      onDetect: (capture) {
        final barcode = capture.barcodes.first;
        final code = barcode.rawValue;

        if (code != null) {
          Navigator.pop(context, code);
        }
      },
      ),
    );
  }
}


class QnaPage extends StatefulWidget {
  const QnaPage({super.key});

  @override
  State<QnaPage> createState() => _QnaPageState();
}

class _QnaPageState extends State<QnaPage> {
  final TextEditingController faqController = TextEditingController();
  final TextEditingController foodSearchController = TextEditingController();
  final TextEditingController logFoodController = TextEditingController();
  final TextEditingController askExpertController = TextEditingController();

  @override
  void dispose() {
    faqController.dispose();
    foodSearchController.dispose();
    logFoodController.dispose();
    askExpertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Q&A Hub'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSection(
              title: "Search FAQs",
              icon: Icons.help_outline,
              controller: faqController,
              hint: "Search common questions...",
              onSubmit: () {
                print("FAQ search: ${faqController.text}");
              },
            ),
            _buildSection(
              title: "Search Food Items",
              icon: Icons.fastfood,
              controller: foodSearchController,
              hint: "Search food (e.g. apple, pizza)...",
              showScanner: true,
              onSubmit: () {
                print("Food search: ${foodSearchController.text}");
              },
            ),
            _buildSection(
              title: "Log New Food Item",
              icon: Icons.add_circle,
              controller: logFoodController,
              hint: "Enter food to log...",
              onSubmit: () {
                print("Log food: ${logFoodController.text}");
              },
            ),
            _buildSection(
              title: "Ask an Expert",
              icon: Icons.medical_services,
              controller: askExpertController,
              hint: "Type your question...",
              onSubmit: () {
                print("Ask expert: ${askExpertController.text}");
              },
            ),
          ],
        ),
      ),
    );
  }

Widget _buildSection({
  required String title,
  required IconData icon,
  required TextEditingController controller,
  required String hint,
  required VoidCallback onSubmit,
  bool showScanner = false,
}) {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: onSubmit,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),

          if (showScanner)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan"),
                onPressed: () async {
                  final code = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BarcodeScannerPage(),
                    ),
                  );

                  if (code != null) {
                    controller.text = code;
                    onSubmit();
                  }
                },
              ),
            ),
        ],
      ),
    ),
  );
}
}