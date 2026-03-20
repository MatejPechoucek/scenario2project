import 'package:flutter/material.dart';

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
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: onSubmit,
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ],
        ),
      ),
    );
  }
}