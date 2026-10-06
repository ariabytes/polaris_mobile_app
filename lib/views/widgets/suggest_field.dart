import 'package:flutter/material.dart';

import 'package:polaris_mobile_app/services/theme_service.dart';

class SuggestField extends StatelessWidget {
  const SuggestField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.decoration,
    required this.optionsFor,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final InputDecoration decoration;
  final List<String> Function(String text) optionsFor;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;

    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: controller,
          focusNode: focusNode,
          optionsBuilder: (value) => optionsFor(value.text),
          fieldViewBuilder: (context, textController, node, onSubmitted) {
            return TextField(
              controller: textController,
              focusNode: node,
              decoration: decoration,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                color: pc.field,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    maxHeight: 200,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Text(option, style: TextStyle(color: pc.ink)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}