import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/presentation/widgets/column_field_icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NumberColumnConfigSection extends StatelessWidget {
  const NumberColumnConfigSection({
    super.key,
    required this.theme,
    required this.hintController,
    required this.prefixController,
    required this.suffixController,
    required this.minController,
    required this.maxController,
    required this.stepController,
    required this.prefixUseIcon,
    required this.suffixUseIcon,
    required this.prefixIconKey,
    required this.suffixIconKey,
    required this.allowDecimals,
    required this.integerOnly,
    required this.positiveOnly,
    required this.showStepper,
  });

  final ThemeData theme;
  final TextEditingController hintController;
  final TextEditingController prefixController;
  final TextEditingController suffixController;
  final TextEditingController minController;
  final TextEditingController maxController;
  final TextEditingController stepController;
  final RxBool prefixUseIcon;
  final RxBool suffixUseIcon;
  final RxnString prefixIconKey;
  final RxnString suffixIconKey;
  final RxBool allowDecimals;
  final RxBool integerOnly;
  final RxBool positiveOnly;
  final RxBool showStepper;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 4),
          Text('Number field options', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: hintController,
            decoration: const InputDecoration(
              labelText: 'Placeholder / hint (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _affixEditor(
            context,
            label: 'Prefix',
            useIcon: prefixUseIcon,
            iconKey: prefixIconKey,
            textController: prefixController,
          ),
          const SizedBox(height: 10),
          _affixEditor(
            context,
            label: 'Suffix',
            useIcon: suffixUseIcon,
            iconKey: suffixIconKey,
            textController: suffixController,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: minController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Minimum value (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: maxController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Maximum value (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: allowDecimals.value,
            onChanged: (bool v) {
              allowDecimals.value = v;
              if (!v) {
                integerOnly.value = true;
              }
            },
            title: const Text('Allow decimals'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: integerOnly.value,
            onChanged: (bool v) {
              integerOnly.value = v;
              if (v) {
                allowDecimals.value = false;
              }
            },
            title: const Text('Integer only mode'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: positiveOnly.value,
            onChanged: (bool v) => positiveOnly.value = v,
            title: const Text('Positive-only restriction'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: showStepper.value,
            onChanged: (bool v) => showStepper.value = v,
            title: const Text('Show + / - buttons'),
          ),
          if (showStepper.value) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: stepController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Step value',
                hintText: '1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _affixEditor(
    BuildContext context, {
    required String label,
    required RxBool useIcon,
    required RxnString iconKey,
    required TextEditingController textController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('$label type', style: theme.textTheme.labelMedium),
        const SizedBox(height: 6),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(value: false, label: Text('Text')),
            ButtonSegment<bool>(value: true, label: Text('Icon')),
          ],
          selected: <bool>{useIcon.value},
          onSelectionChanged: (Set<bool> next) {
            if (next.isEmpty) {
              return;
            }
            useIcon.value = next.first;
            if (useIcon.value) {
              textController.clear();
            } else {
              iconKey.value = null;
            }
          },
        ),
        const SizedBox(height: 6),
        if (!useIcon.value)
          TextField(
            controller: textController,
            decoration: InputDecoration(
              labelText: '$label text (optional)',
              hintText: label == 'Prefix' ? r'$, Qty:' : 'kg, pcs, %',
              border: const OutlineInputBorder(),
            ),
          )
        else
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  (iconKey.value == null || iconKey.value!.isEmpty)
                      ? '$label icon (optional): none'
                      : '$label icon: ${iconKey.value}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () async {
                  final String? picked = await showColumnFieldIconPicker(
                    context,
                    currentKey: iconKey.value,
                  );
                  iconKey.value = picked;
                },
                icon: Icon(
                  (iconKey.value == null || iconKey.value!.isEmpty)
                      ? Icons.add_circle_outline
                      : AppIconRegistry.iconOf(iconKey.value!),
                ),
                tooltip: 'Choose icon',
              ),
              if (iconKey.value != null && iconKey.value!.isNotEmpty)
                IconButton(
                  onPressed: () => iconKey.value = null,
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear',
                ),
            ],
          ),
      ],
    );
  }
}
