// lib/screens/model_status_screen.dart

import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';

class ModelStatusScreen extends StatefulWidget {
  const ModelStatusScreen({Key? key}) : super(key: key);

  @override
  State<ModelStatusScreen> createState() => _ModelStatusScreenState();
}

class _ModelStatusScreenState extends State<ModelStatusScreen> {
  final CactusLM _llm = CactusLM();
  List<CactusModel> models = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkModels();
  }

  Future<void> _checkModels() async {
    setState(() => isLoading = true);

    try {
      final fetchedModels = await _llm.getModels();
      setState(() {
        models = fetchedModels;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching models: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Model Status')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: models.length,
              itemBuilder: (context, index) {
                final model = models[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      model.isDownloaded ? Icons.check_circle : Icons.download,
                      color: model.isDownloaded ? Colors.green : Colors.grey,
                    ),
                    title: Text(model.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Slug: ${model.slug}'),
                        Text('Size: ${model.sizeMb} MB'),
                        Text('Downloaded: ${model.isDownloaded ? "✅ Yes" : "❌ No"}'),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkModels,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}