import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/validators.dart';

void main() {
  group('Formatação de Nome', () {
    test('deve capitalizar primeira letra de cada palavra', () {
      expect(Validators.formatarNome('joão silva'), 'João Silva');
      expect(Validators.formatarNome('MARIA SANTOS'), 'Maria Santos');
      expect(Validators.formatarNome('ana LUCIA'), 'Ana Lucia');
    });

    test('deve remover espaços extras', () {
      expect(Validators.formatarNome('  joão   silva  '), 'João Silva');
      expect(Validators.formatarNome('maria  santos'), 'Maria Santos');
    });

    test('deve lidar com nomes compostos', () {
      expect(Validators.formatarNome('josé da silva'), 'José Da Silva');
      expect(Validators.formatarNome('ana maria dos santos'), 'Ana Maria Dos Santos');
    });

    test('deve lidar com entrada vazia', () {
      expect(Validators.formatarNome(''), '');
      expect(Validators.formatarNome('   '), '');
    });
  });
}