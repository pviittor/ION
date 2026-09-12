import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/validators.dart';

void main() {
  group('Validação de Telefone', () {
    test('deve retornar erro quando telefone está vazio', () {
      expect(Validators.validarTelefone(''), 'Telefone é obrigatório');
      expect(Validators.validarTelefone(null), 'Telefone é obrigatório');
    });

    test('deve retornar erro quando telefone tem menos de 10 dígitos', () {
      expect(Validators.validarTelefone('123456789'), 'Telefone deve ter pelo menos 10 dígitos');
      expect(Validators.validarTelefone('(11) 1234-567'), 'Telefone deve ter pelo menos 10 dígitos');
    });

    test('deve retornar erro quando telefone tem mais de 11 dígitos', () {
      expect(Validators.validarTelefone('123456789012'), 'Telefone deve ter no máximo 11 dígitos');
    });

    test('deve retornar erro quando celular não começa com 9', () {
      expect(Validators.validarTelefone('11812345678'), 'Número de celular deve começar com 9');
    });

    test('deve retornar erro quando código de área é inválido', () {
      expect(Validators.validarTelefone('0912345678'), 'Código de área inválido');
      expect(Validators.validarTelefone('1012345678'), 'Código de área inválido');
    });

    test('deve aceitar telefones fixos válidos', () {
      expect(Validators.validarTelefone('1112345678'), null);
      expect(Validators.validarTelefone('(11) 1234-5678'), null);
    });

    test('deve aceitar celulares válidos', () {
      expect(Validators.validarTelefone('11987654321'), null);
      expect(Validators.validarTelefone('(11) 98765-4321'), null);
    });
  });

  group('Formatação de Telefone', () {
    test('deve formatar telefone fixo corretamente', () {
      expect(Validators.formatarTelefone('1112345678'), '(11) 1234-5678');
    });

    test('deve formatar celular corretamente', () {
      expect(Validators.formatarTelefone('11987654321'), '(11) 98765-4321');
    });

    test('deve retornar telefone original se não for possível formatar', () {
      expect(Validators.formatarTelefone('123'), '123');
      expect(Validators.formatarTelefone('abc'), 'abc');
    });
  });
}