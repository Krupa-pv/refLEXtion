import 'dart:math';

class WordGeneration {

  final List<String> wordSet = ['apple', 'banana', 'cherry', 'dandelion', 'elephant'];

  String generate_word(){

    final random = Random();
    int random_index = random.nextInt(wordSet.length);
    return wordSet[random_index];

  }


}