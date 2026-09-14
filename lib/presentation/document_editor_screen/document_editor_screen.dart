import 'package:flutter/material.dart';

class DocumentEditorScreen extends StatefulWidget {
  final dynamic documentData;
  const DocumentEditorScreen({super.key, this.documentData});

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Editor')),
      body: const Center(child: Text('Editor Loaded')),
    );
  }
}
