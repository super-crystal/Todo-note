enum TagInputError { tooMany, tooLong }

abstract final class TaskTags {
  static const maxCount = 5;
  static const maxLength = 16;
  static const maxInputLength = 120;

  static List<String> normalize(Iterable<String> values) {
    final seen = <String>{};
    return List.unmodifiable(
      values
          .map((value) => value.trim().replaceFirst(RegExp(r'^#+'), ''))
          .where((value) => value.isNotEmpty && seen.add(value.toLowerCase())),
    );
  }

  static List<String> parse(String input) =>
      normalize(input.split(RegExp(r'[,，;；\s]+')));

  static TagInputError? validate(Iterable<String> values) {
    final tags = normalize(values);
    if (tags.length > maxCount) return TagInputError.tooMany;
    if (tags.any((value) => value.length > maxLength)) {
      return TagInputError.tooLong;
    }
    return null;
  }
}
