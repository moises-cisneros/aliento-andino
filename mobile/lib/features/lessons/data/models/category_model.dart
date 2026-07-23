/// Modelo de categoría de lecciones.
class CategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final int order;
  final int lessonsCount;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.order = 0,
    this.lessonsCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      order: json['order'] as int? ?? 0,
      lessonsCount: json['lessons_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'order': order,
    'lessons_count': lessonsCount,
  };
}
