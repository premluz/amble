/// Per-occurrence state of one plan field (docs/RECURRENCE_CONTRACT.md §4).
///
/// Two families, so the type system rejects "cleared" where it means nothing:
/// - [FieldOverride]: inherited or set (e.g. title — never empty).
/// - [ClearableOverride]: inherited, set, or explicitly cleared
///   (e.g. description removed for this one day).
///
/// "Inherited" and "cleared" are distinct values on purpose: no value stored
/// is not the same as the user removing the value.
sealed class ClearableOverride<T> {
  const ClearableOverride();
}

sealed class FieldOverride<T> implements ClearableOverride<T> {
  const FieldOverride();
}

final class Inherit<T> extends FieldOverride<T> {
  const Inherit();
}

final class SetTo<T> extends FieldOverride<T> {
  const SetTo(this.value);
  final T value;
}

final class Clear<T> extends ClearableOverride<T> {
  const Clear();
}

T resolveField<T>(FieldOverride<T> field, T inherited) => switch (field) {
  Inherit<T>() => inherited,
  SetTo<T>(:final value) => value,
};

T? resolveClearable<T>(ClearableOverride<T> field, T? inherited) =>
    switch (field) {
      Inherit<T>() => inherited,
      SetTo<T>(:final value) => value,
      Clear<T>() => null,
    };

bool isOverridden<T>(ClearableOverride<T> field) => field is! Inherit<T>;

const _setKey = 'set';
const _clearKey = 'clear';

/// JSON form: absent (null) = inherited, `{"set": v}`, `{"clear": true}`.
Object? encodeOverride<T>(
  ClearableOverride<T> field,
  Object? Function(T value) encode,
) => switch (field) {
  Inherit<T>() => null,
  SetTo<T>(:final value) => {_setKey: encode(value)},
  Clear<T>() => {_clearKey: true},
};

FieldOverride<T> decodeFieldOverride<T>(
  Object? raw,
  T Function(Object? value) decode,
  String field,
) {
  final decoded = decodeClearableOverride(raw, decode, field);
  if (decoded is! FieldOverride<T>) {
    throw FormatException('Field "$field" cannot be cleared');
  }
  return decoded;
}

ClearableOverride<T> decodeClearableOverride<T>(
  Object? raw,
  T Function(Object? value) decode,
  String field,
) {
  if (raw == null) return Inherit<T>();
  if (raw is Map && raw.length == 1) {
    if (raw.containsKey(_setKey)) return SetTo<T>(decode(raw[_setKey]));
    if (raw[_clearKey] == true) return Clear<T>();
  }
  throw FormatException('Invalid override for field "$field"');
}

String decodeString(Object? value) {
  if (value is String) return value;
  throw FormatException('Expected a string, got $value');
}

int decodeInt(Object? value) {
  if (value is int) return value;
  throw FormatException('Expected an int, got $value');
}

bool decodeBool(Object? value) {
  if (value is bool) return value;
  throw FormatException('Expected a bool, got $value');
}

Object? encodeIdentity<T>(T value) => value;
