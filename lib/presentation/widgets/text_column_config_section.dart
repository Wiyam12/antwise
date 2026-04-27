import 'package:antwise/core/icons/app_icon_registry.dart';
import 'package:antwise/domain/entities/table_text_validation_kind.dart';
import 'package:antwise/presentation/widgets/column_field_icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Step 4 (columns) extra options when data type is Text.
class TextColumnConfigSection extends StatelessWidget {
  const TextColumnConfigSection({
    super.key,
    required this.theme,
    required this.hintController,
    required this.customPatternController,
    required this.validationKind,
    required this.prefixIconKey,
    required this.suffixIconKey,
  });

  final ThemeData theme;
  final TextEditingController hintController;
  final TextEditingController customPatternController;
  final Rx<TableTextValidationKind> validationKind;
  final RxnString prefixIconKey;
  final RxnString suffixIconKey;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final TableTextValidationKind v = validationKind.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 4),
          Text('Text field options', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: hintController,
            decoration: const InputDecoration(
              labelText: 'Placeholder / hint (optional)',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _iconRow(
            context,
            label: 'Prefix icon',
            iconKey: prefixIconKey,
          ),
          const SizedBox(height: 8),
          _iconRow(
            context,
            label: 'Suffix icon',
            iconKey: suffixIconKey,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TableTextValidationKind>(
            value: v,
            decoration: const InputDecoration(
              labelText: 'Validation',
              border: OutlineInputBorder(),
            ),
            items:
                <DropdownMenuItem<TableTextValidationKind>>[
                  const DropdownMenuItem<TableTextValidationKind>(
                    value: TableTextValidationKind.none,
                    child: Text('None'),
                  ),
                  const DropdownMenuItem<TableTextValidationKind>(
                    value: TableTextValidationKind.email,
                    child: Text('Email'),
                  ),
                  const DropdownMenuItem<TableTextValidationKind>(
                    value: TableTextValidationKind.phone,
                    child: Text('Phone number'),
                  ),
                  const DropdownMenuItem<TableTextValidationKind>(
                    value: TableTextValidationKind.password,
                    child: Text('Password (masked input)'),
                  ),
                  const DropdownMenuItem<TableTextValidationKind>(
                    value: TableTextValidationKind.username,
                    child: Text('Username'),
                  ),
                  const DropdownMenuItem<TableTextValidationKind>(
                    value: TableTextValidationKind.custom,
                    child: Text('Custom pattern (regex)'),
                  ),
                ],
            onChanged: (TableTextValidationKind? next) {
              if (next == null) {
                return;
              }
              validationKind.value = next;
            },
          ),
          if (v == TableTextValidationKind.custom) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: customPatternController,
              decoration: const InputDecoration(
                labelText: 'Regular expression',
                hintText: r'^[A-Za-z0-9]+$',
                border: OutlineInputBorder(),
                helperText: 'Full match against the value',
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _iconRow(
    BuildContext context, {
    required String label,
    required RxnString iconKey,
  }) {
    return Obx(() {
      final String? key = iconKey.value;
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              key == null || key.isEmpty
                  ? '$label (optional): none'
                  : '$label: $key',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () async {
              final String? picked = await showColumnFieldIconPicker(
                context,
                currentKey: key,
              );
              iconKey.value = picked;
            },
            icon: Icon(
              key == null || key.isEmpty
                  ? Icons.add_circle_outline
                  : AppIconRegistry.iconOf(key),
              size: 22,
            ),
            tooltip: 'Choose icon',
          ),
          if (key != null && key.isNotEmpty)
            IconButton(
              onPressed: () => iconKey.value = null,
              icon: const Icon(Icons.clear, size: 20),
              tooltip: 'Clear',
            ),
        ],
      );
    });
  }
}
