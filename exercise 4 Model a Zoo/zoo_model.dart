/// Exercise 4: Model a Zoo
/// 
/// Task: Create a class hierarchy for animals.
/// - Abstract class Animal with name and abstract makeSound().
/// - Two concrete subclasses: Dog and Cat, each with their own sound.
/// - Add a property legs to Animal (override appropriately).
/// - Create a list of animals, iterate and print each sound.

abstract class Animal {
  final String name;
  final int legs;

  Animal(this.name, this.legs);

  void makeSound();
}

class Dog extends Animal {
  Dog(String name) : super(name, 4);

  @override
  void makeSound() {
    print('$name says Woof!');
  }
}

class Cat extends Animal {
  Cat(String name) : super(name, 4);

  @override
  void makeSound() {
    print('$name says Meow!');
  }
}

void main() {
  final animals = <Animal>[
    Dog('Buddy'),
    Cat('Whiskers'),
  ];

  for (final animal in animals) {
    animal.makeSound();
  }
}
