// lib/widgets/signature_pad.dart

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignaturePad extends StatefulWidget {
  final SignatureController controller;
  const SignaturePad({super.key, required this.controller});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Signature(
            controller: widget.controller,
            height: 150,
            backgroundColor: Colors.grey[200]!,
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.undo),
                  color: Theme.of(context).primaryColor,
                  onPressed: () {
                    if (widget.controller.isNotEmpty) {
                      widget.controller.undo();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  color: Theme.of(context).primaryColor,
                  onPressed: () {
                    if (widget.controller.canRedo) {
                      widget.controller.redo();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  color: Colors.red,
                  onPressed: () => widget.controller.clear(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
