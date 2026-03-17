# Exercise 4: Model a Zoo

This exercise demonstrates the use of **inheritance**, **abstract classes**, and **polymorphism** in Dart.

## Task
- Create an abstract class `Animal` with a `name` and an abstract `makeSound()` method.
- Add a `legs` property to `Animal`.
- Create two concrete subclasses: `Dog` and `Cat`, each implementing `makeSound()` with their specific sounds.
- Create a list of animals, iterate through it, and print each animal's sound.

## Implementation (Dart)

```dart
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
```

## How to Run
Open `zoo_model.dart` and run it using the Dart SDK:
```bash
dart zoo_model.dart
```

## Expected Output
```
Buddy says Woof!
Whiskers says Meow!
```
