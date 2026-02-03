---
paths:
  - "lib/**/*model*.dart"
  - "lib/**/*dto*.dart"
---

# Serialization Rules for PharmaScan

## JSON Serialization

Use `json_serializable` for model serialization:

```dart
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Product {
  final String cip13;
  final String name;
  final double price;

  Product({required this.cip13, required this.name, required this.price});

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
```

## Field Naming

Use `FieldRename.snake` to convert Dart `camelCase` to JSON `snake_case`.

## Generated Files

- **NEVER edit** `*.g.dart` files
- **ALWAYS regenerate** after model changes:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

## When to Use

Serialize to JSON only when:
- Receiving data from external APIs
- Persisting to non-Drift storage
- Caching in shared preferences

Drift handles SQLite serialization automatically.

## References

- [json_serializable](https://pub.dev/packages/json_annotation)
