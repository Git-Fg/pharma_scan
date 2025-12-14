import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../atoms/app_text.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Enumération des variantes d'input
enum InputVariant { 
  filled,    // Champ avec fond
  outlined,  // Champ avec bordure
  underlined // Champ avec soulignement seulement
}

/// Enumération des types d'input
enum InputType { 
  text,
  email, 
  password,
  number,
  phone,
  url,
  search,
}

/// Widget d'input standardisé
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.controller,
    this.focusNode,
    required this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.variant = InputVariant.outlined,
    this.type = InputType.text,
    this.textCapitalization = TextCapitalization.sentences,
    this.textAlign = TextAlign.start,
    this.contentPadding,
    this.margin,
    this.fillColor,
    this.borderColor,
    this.borderRadius,
    this.cursorColor,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.smartDashesType,
    this.smartQuotesType,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final InputVariant variant;
  final InputType type;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? margin;
  final Color? fillColor;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final Color? cursorColor;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  TextInputType get _effectiveKeyboardType {
    if (widget.keyboardType != null) {
      return widget.keyboardType!;
    }
    
    return switch (widget.type) {
      InputType.email => TextInputType.emailAddress,
      InputType.password => TextInputType.visiblePassword, // On gère l'obscurcissement séparément
      InputType.number => TextInputType.number,
      InputType.phone => TextInputType.phone,
      InputType.url => TextInputType.url,
      InputType.search => TextInputType.text,
      _ => TextInputType.text,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final effectiveBorderColor = hasError 
      ? context.textNegative 
      : (widget.borderColor ?? context.actionSurface);

    final inputDecoration = InputDecoration(
      labelText: widget.label,
      hintText: widget.placeholder ?? widget.hintText,
      helperText: widget.helperText,
      errorText: widget.errorText,
      prefixIcon: widget.prefixIcon,
      suffixIcon: _buildSuffixIcon(),
      filled: widget.variant != InputVariant.outlined,
      fillColor: widget.fillColor ?? (hasError 
        ? context.surfaceNegative 
        : context.surfaceSecondary),
      border: _getBorder((widget.borderRadius ?? context.radiusMedium) as BorderRadius, effectiveBorderColor),
      enabledBorder: _getBorder((widget.borderRadius ?? context.radiusMedium) as BorderRadius, effectiveBorderColor),
      focusedBorder: _getBorder(
        (widget.borderRadius ?? context.radiusMedium) as BorderRadius,
        hasError ? context.textNegative : context.actionPrimary,
        width: 2.0,
      ),
      errorBorder: _getBorder(
        (widget.borderRadius ?? context.radiusMedium) as BorderRadius,
        context.textNegative,
        width: 2.0,
      ),
      focusedErrorBorder: _getBorder(
        (widget.borderRadius ?? context.radiusMedium) as BorderRadius,
        context.textNegative,
        width: 2.0,
      ),
      contentPadding: widget.contentPadding ?? const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      alignLabelWithHint: true,
    );

    return Container(
      margin: widget.margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            widget.label,
            variant: TextVariant.labelMedium,
            color: hasError ? context.textNegative : context.textSecondary,
          ),
          Gap(AppSpacing.small),
          TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            decoration: inputDecoration,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            inputFormatters: widget.inputFormatters,
            keyboardType: _effectiveKeyboardType,
            obscureText: _obscureText,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            textCapitalization: widget.textCapitalization,
            textAlign: widget.textAlign,
            cursorColor: widget.cursorColor ?? context.actionPrimary,
            autofocus: widget.autofocus,
            autocorrect: widget.autocorrect,
            enableSuggestions: widget.enableSuggestions,
            smartDashesType: widget.smartDashesType,
            smartQuotesType: widget.smartQuotesType,
          ),
        ],
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    final List<Widget> suffixIcons = [];

    // Ajouter le suffixe d'icône personnalisé
    if (widget.suffixIcon != null) {
      suffixIcons.add(widget.suffixIcon!);
    }

    // Ajouter l'icône de visibilité pour les champs de mot de passe
    if (widget.type == InputType.password) {
      suffixIcons.add(
        IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: context.textSecondary,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      );
    }

    // Ajouter l'icône de compteur de caractères
    if (widget.maxLength != null && widget.controller != null) {
      suffixIcons.add(
        AppText(
          '${widget.controller!.text.length}/${widget.maxLength}',
          variant: TextVariant.labelSmall,
          color: context.textSecondary,
        ),
      );
    }

    if (suffixIcons.isEmpty) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: suffixIcons,
    );
  }

  OutlineInputBorder _getBorder(BorderRadius borderRadius, Color borderSideColor, {double width = 1.0}) {
    return OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: borderSideColor,
        width: width,
      ),
    );
  }
}