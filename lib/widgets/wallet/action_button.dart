import 'package:citizenwallet/theme/provider.dart';
import 'package:flutter/cupertino.dart';

class WalletActionButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String text;
  final double buttonSize;
  final double buttonIconSize;
  final double buttonFontSize;
  final EdgeInsets? margin;
  final double shrink;
  final bool alt;
  final bool loading;
  final bool disabled;
  final void Function()? onPressed;
  final int? buttonCount; // Number of buttons to help calculate available space

  const WalletActionButton({
    super.key,
    this.icon,
    this.customIcon,
    required this.text,
    this.buttonSize = 60,
    this.buttonIconSize = 40,
    this.buttonFontSize = 14,
    this.margin,
    this.shrink = 0.0,
    this.alt = false,
    this.loading = false,
    this.disabled = false,
    this.buttonCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final small = (1 - shrink) < 0.90;
    // Adjust button width based on button count when in small state
    // With 4 buttons, each button needs to be narrower
    final baseButtonWidth = small ? 110.0 : buttonSize;
    final buttonWidth = (buttonCount != null && buttonCount! > 3 && small)
        ? (baseButtonWidth * 0.75).clamp(70.0, 90.0)
        : baseButtonWidth;

    final color = alt
        ? Theme.of(context).colors.surfacePrimary.resolveFrom(context)
        : Theme.of(context).colors.white;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        height: buttonSize + 40,
        width: buttonWidth,
        margin: margin,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: disabled ? () => () : onPressed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: buttonSize,
                width: buttonWidth,
                decoration: BoxDecoration(
                  color: alt
                      ? Theme.of(context).colors.white
                      : Theme.of(context)
                          .colors
                          .surfacePrimary
                          .resolveFrom(context),
                  borderRadius: BorderRadius.circular(buttonSize / 2),
                  border: alt
                      ? Border.all(
                          color: Theme.of(context)
                              .colors
                              .surfacePrimary
                              .resolveFrom(context),
                          width: 3.0,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: small
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                                fontSize: (buttonCount != null && buttonCount! > 3) ? 12.0 : 14.0,
                              ),
                            ),
                          ),
                          SizedBox(width: (buttonCount != null && buttonCount! > 3) ? 6.0 : 10.0),
                          customIcon ??
                              Icon(
                                icon,
                                size: (buttonCount != null && buttonCount! > 3) ? 16.0 : 18.0,
                                color: color,
                              ),
                        ],
                      )
                    : Center(
                        child: customIcon ??
                            Icon(
                              icon,
                              size: buttonIconSize,
                              color: color,
                            ),
                      ),
              ),
            ),
            if (!small)
              Expanded(
                child: Center(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colors.text.resolveFrom(context),
                      fontSize: buttonFontSize,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
