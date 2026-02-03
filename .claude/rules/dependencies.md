---
paths:
  - "pubspec.yaml"
  - "**/pubspec.yaml"
---

# Dependency Management for PharmaScan

## Adding Dependencies

```bash
# Regular dependency
dart pub add <package_name>

# Dev dependency
dart pub add --dev <package_name>

# Specific version
dart pub add riverpod:^3.1.0

# Override (temporary fix)
dart pub add override:riverpod:3.1.1
```

## Removing Dependencies

```bash
dart pub remove <package_name>
```

## Current Constraints

| Package | Constraint | Reason |
|---------|------------|--------|
| riverpod | 3.1.x | Flutter 3.38 SDK constraint |
| analyzer | <9.0.0 | Required by test_api |

## Never Do

- Manually edit `pubspec.yaml` - always use `dart pub`
- Use `dependency_overrides` for permanent fixes
- Add conflicting version constraints

## References

- [Dart Pub Documentation](https://dart.dev/tools/pub/cmd)
