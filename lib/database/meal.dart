class Meal {
  final int? id;
  final String name;
  final String description;
  final int calories;

  const Meal({
    this.id,
    required this.name,
    required this.description,
    required this.calories,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'calories': calories,
  };

  factory Meal.fromMap(Map<String, Object?> map) => Meal(
    id: map['id'] as int?,
    name: map['name'] as String,
    description: map['description'] as String,
    calories: map['calories'] as int,
  );
}
