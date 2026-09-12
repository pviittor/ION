import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/validators.dart';

void main() {
  group('Validação de Nome', () {
    test('deve retornar erro quando nome está vazio', () {
      expect(Validators.validarNome(''), 'Nome é obrigatório');
      expect(Validators.validarNome(null), 'Nome é obrigatório');
      expect(Validators.validarNome('   '), 'Nome é obrigatório');
    });

    test('deve retornar erro quando nome tem menos de 2 caracteres', () {
      expect(Validators.validarNome('A'), 'Nome deve ter pelo menos 2 caracteres');
    });

    test('deve retornar erro quando nome tem mais de 50 caracteres', () {
      String nomeLongo = 'A' * 51;
      expect(Validators.validarNome(nomeLongo), 'Nome deve ter no máximo 50 caracteres');
    });

    test('deve retornar erro quando nome contém números', () {
      expect(Validators.validarNome('João123'), 'Nome não pode conter números');
      expect(Validators.validarNome('Maria2'), 'Nome não pode conter números');
    });

    test('deve retornar erro quando nome contém caracteres especiais', () {
      expect(Validators.validarNome('João@'), 'Nome deve conter apenas letras');
      expect(Validators.validarNome('Maria#'), 'Nome deve conter apenas letras');
    });

    test('deve aceitar nomes válidos', () {
      expect(Validators.validarNome('João'), null);
      expect(Validators.validarNome('Maria Silva'), null);
      expect(Validators.validarNome('José da Silva'), null);
      expect(Validators.validarNome('Ana Lúcia'), null);
    });

    test('deve aceitar nomes com acentos', () {
      expect(Validators.validarNome('José'), null);
      expect(Validators.validarNome('Ângela'), null);
      expect(Validators.validarNome('Antônio'), null);
    });
  });

  group('Validação de Sobrenome', () {
    test('deve retornar erro quando sobrenome está vazio', () {
      expect(Validators.validarSobrenome(''), 'Sobrenome é obrigatório');
      expect(Validators.validarSobrenome(null), 'Sobrenome é obrigatório');
    });

    test('deve retornar erro quando sobrenome tem menos de 2 caracteres', () {
      expect(Validators.validarSobrenome('S'), 'Sobrenome deve ter pelo menos 2 caracteres');
    });

    test('deve retornar erro quando sobrenome contém números', () {
      expect(Validators.validarSobrenome('Silva123'), 'Sobrenome não pode conter números');
    });

    test('deve aceitar sobrenomes válidos', () {
      expect(Validators.validarSobrenome('Silva'), null);
      expect(Validators.validarSobrenome('Santos'), null);
      expect(Validators.validarSobrenome('da Silva'), null);
    });
  });
}