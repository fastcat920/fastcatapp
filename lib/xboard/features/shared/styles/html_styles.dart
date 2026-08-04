import 'package:fl_clash/common/color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

/// HTML样式配置
/// 用于统一管理应用内HTML内容的显示样式
class NoticeHtmlStyles {
  /// 将Color转换为CSS颜色字符串
  static String _colorToHex(Color color) {
    final argb = color.value32bit;
    return '#${argb.toRadixString(16).substring(2)}';
  }

  /// 获取通知内容的HTML Widget配置
  static HtmlWidget buildNoticeHtml({
    required BuildContext context,
    required String htmlContent,
    required Function(String?)? onTapUrl,
    bool preserveDocumentStyles = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return HtmlWidget(
      htmlContent,
      onTapUrl: (url) {
        onTapUrl?.call(url);
        return true; // 返回true表示已处理
      },
      textStyle: preserveDocumentStyles
          ? textTheme.bodyMedium?.copyWith(height: 1.6)
          : textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              height: 1.6,
            ),
      customStylesBuilder: (element) {
        if (preserveDocumentStyles) {
          final classes =
              element.classes.map((item) => item.toLowerCase()).toSet();
          final isButtonLike =
              element.attributes['data-fastcat-button'] == 'true' ||
                  element.localName == 'button' ||
                  (element.localName == 'a' &&
                      classes.any(
                        (item) =>
                            item.contains('btn') ||
                            item.contains('button') ||
                            item.contains('chip'),
                      ));
          if (isButtonLike) {
            final isPrimary = classes.any(
              (item) =>
                  item.contains('primary') ||
                  item.contains('main') ||
                  item.contains('filled') ||
                  item.contains('solid'),
            );
            final isOutline = classes.any(
              (item) =>
                  item.contains('outline') ||
                  item.contains('ghost') ||
                  item.contains('secondary'),
            );
            final backgroundColor = isOutline
                ? 'transparent'
                : _colorToHex(
                    isPrimary
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                  );
            final foregroundColor = isOutline
                ? _colorToHex(colorScheme.primary)
                : _colorToHex(
                    isPrimary ? colorScheme.onPrimary : colorScheme.onSurface,
                  );
            return {
              'display': 'inline-block',
              'padding': '10px 16px',
              'border-radius': '999px',
              'background-color': backgroundColor,
              'color': foregroundColor,
              'text-decoration': 'none',
              'font-weight': '500',
              'border':
                  '1px solid ${_colorToHex(isOutline ? colorScheme.primary : Colors.transparent)}',
            };
          }
          switch (element.localName) {
            case 'body':
              return {
                'color': _colorToHex(colorScheme.onSurface),
                'background-color': _colorToHex(colorScheme.surface),
              };
            case 'img':
              return {
                'max-width': '100%',
                'height': 'auto',
              };
            case 'table':
              return {
                'max-width': '100%',
              };
            case 'a':
              return {
                'color': _colorToHex(colorScheme.primary),
              };
            default:
              return null;
          }
        }
        // 根据不同的HTML标签返回对应的样式
        switch (element.localName) {
          case 'h1':
            return {
              'font-size': '${textTheme.titleLarge?.fontSize ?? 22}px',
              'font-weight': '500',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '16px 0 12px 0',
            };
          case 'h2':
            return {
              'font-size': '${textTheme.titleMedium?.fontSize ?? 16}px',
              'font-weight': '500',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '14px 0 10px 0',
            };
          case 'h3':
            return {
              'font-size': '${textTheme.bodyLarge?.fontSize ?? 16}px',
              'font-weight': '500',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '12px 0 8px 0',
            };
          case 'h4':
          case 'h5':
          case 'h6':
            return {
              'font-size': '${textTheme.bodyMedium?.fontSize ?? 14}px',
              'font-weight': '500',
              'color': _colorToHex(colorScheme.onSurface),
              'line-height': '1.3',
              'margin': '10px 0 8px 0',
            };
          case 'p':
            return {
              'margin': '0 0 12px 0',
              'line-height': '1.6',
            };
          case 'a':
            return {
              'color': _colorToHex(colorScheme.primary),
              'text-decoration': 'underline',
            };
          case 'code':
            return {
              'font-family': 'monospace',
              'font-size': '${(textTheme.bodySmall?.fontSize ?? 12)}px',
              'background-color':
                  _colorToHex(colorScheme.surfaceContainerHighest),
              'color': _colorToHex(colorScheme.tertiary),
              'padding': '2px 4px',
              'border-radius': '4px',
            };
          case 'pre':
            return {
              'font-family': 'monospace',
              'font-size': '${textTheme.bodySmall?.fontSize ?? 12}px',
              'background-color':
                  _colorToHex(colorScheme.surfaceContainerHighest),
              'padding': '12px',
              'margin': '8px 0',
              'border':
                  '1px solid ${_colorToHex(colorScheme.outline.withValues(alpha: 0.2))}',
              'border-radius': '8px',
              'overflow': 'auto',
            };
          case 'blockquote':
            return {
              'color':
                  _colorToHex(colorScheme.onSurface.withValues(alpha: 0.7)),
              'font-style': 'italic',
              'border-left':
                  '4px solid ${_colorToHex(colorScheme.primary.withValues(alpha: 0.5))}',
              'padding-left': '12px',
              'margin': '8px 0',
            };
          case 'ul':
          case 'ol':
            return {
              'margin': '8px 0',
              'padding-left': '20px',
            };
          case 'li':
            return {
              'margin-bottom': '4px',
            };
          case 'strong':
          case 'b':
            return {
              'font-weight': '500',
            };
          case 'em':
          case 'i':
            return {
              'font-style': 'italic',
            };
          case 'hr':
            return {
              'border': 'none',
              'border-top':
                  '1px solid ${_colorToHex(colorScheme.outline.withValues(alpha: 0.3))}',
              'margin': '16px 0',
            };
          case 'img':
            return {
              'margin': '8px 0',
              'max-width': '100%',
              'height': 'auto',
            };
          default:
            return null;
        }
      },
      // 启用功能
      enableCaching: true,
      renderMode: RenderMode.column,
    );
  }
}
