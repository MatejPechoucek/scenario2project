import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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

  String faqAnswer = "";
  String foodSearchAnswer = "";
  String logFoodAnswer = "";
  String expertAnswer = "";


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
            response: faqAnswer,
            onSubmit: () {
              setState(() {
                if (faqController.text.toLowerCase().contains("calories")) {
                  faqAnswer = "Calories measure the energy in food.";
                } else {
                  faqAnswer = "No FAQ found. Try another question.";
                }
              });
            },
          ),
          _buildSection(
            title: "Search Food Items",
            icon: Icons.fastfood,
            controller: foodSearchController,
            hint: "Search food (e.g. apple, pizza)...",
            showScanner: true,
            response: foodSearchAnswer,
            onSubmit: () {
              setState(() {
                if (foodSearchController.text.toLowerCase() == "apple") {
                  foodSearchAnswer = "Apple: ~52 kcal per 100g";
                } else if (foodSearchController.text.toLowerCase() == "pizza") {
                  foodSearchAnswer = "Pizza: ~266 kcal per slice";
                } else {
                  foodSearchAnswer = "Food not found.";
                }
              });
            },
          ),
          _buildSection(
            title: "Log New Food Item",
            icon: Icons.add_circle,
            controller: logFoodController,
            hint: "Enter food to log...",
            response: logFoodAnswer,
            onSubmit: () {
              setState(() {
                logFoodAnswer = "Food '${logFoodController.text}' logged successfully!";
              });
            },
          ),
          _buildSection(
            title: "Ask an Expert",
            icon: Icons.medical_services,
            controller: askExpertController,
            hint: "Type your question...",
            response: expertAnswer,
            onSubmit: () {
              setState(() {
                expertAnswer = "An expert will respond to your question soon.";
              });
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
  String response = "",
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
            if (response.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              response,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ],
      ),
    ),
  );
}
}