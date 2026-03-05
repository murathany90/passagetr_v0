import 'package:flutter/material.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.actionLabel,
    this.onActionTap,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Text titleText = Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        );

        if (actionLabel == null) {
          if (constraints.hasBoundedWidth) {
            return Row(
              children: <Widget>[
                Expanded(child: titleText),
              ],
            );
          }
          return titleText;
        }

        if (constraints.hasBoundedWidth) {
          return Row(
            children: <Widget>[
              Expanded(child: titleText),
              TextButton(
                onPressed: onActionTap,
                child: Text(actionLabel!),
              ),
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              fit: FlexFit.loose,
              child: titleText,
            ),
            TextButton(
              onPressed: onActionTap,
              child: Text(actionLabel!),
            ),
          ],
        );
      },
    );
  }
}
