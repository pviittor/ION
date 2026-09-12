import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/validators.dart';

void main() {
  group('Validação de Email', () {
    test('deve retornar erro quando email está vazio', () {
      expect(Validators.validarEmail(''), 'Por favor, insira seu email');
      expect(Validators.validarEmail(null), 'Por favor, insira seu email');
    });

    test('deve retornar erro quando email não contém @', () {
      expect(Validators.validarEmail('emailinvalido.com'), 'Por favor, insira um email válido');
    });

    test('deve retornar erro quando email não contém ponto', () {
      expect(Validators.validarEmail('email@invalid'), 'Por favor, insira um email válido');
    });

    test('deve aceitar emails válidos', () {
      expect(Validators.validarEmail('teste@email.com'), null);
      expect(Validators.validarEmail('usuario@dominio.com.br'), null);
    });
  });

  group('Validação de Senha', () {
    test('deve retornar erro quando senha está vazia', () {
      expect(Validators.validarSenha(''), 'Por favor, insira sua senha');
      expect(Validators.validarSenha(null), 'Por favor, insira sua senha');
    });

    test('deve retornar erro quando senha tem menos de 6 caracteres', () {
      expect(Validators.validarSenha('12345'), 'A senha deve ter pelo menos 6 caracteres');
    });

    test('deve aceitar senhas válidas', () {
      expect(Validators.validarSenha('123456'), null);
      expect(Validators.validarSenha('senhaSegura123'), null);
    });
  });

  group('Validação de Confirmação de Senha', () {
    test('deve retornar erro quando confirmação está vazia', () {
      expect(Validators.validarConfirmacaoSenha('', '123456'), 'Confirme sua senha');
      expect(Validators.validarConfirmacaoSenha(null, '123456'), 'Confirme sua senha');
    });

    test('deve retornar erro quando senhas não coincidem', () {
      expect(Validators.validarConfirmacaoSenha('123456', '654321'), 'As senhas não coincidem');
    });

    test('deve aceitar quando senhas coincidem', () {
      expect(Validators.validarConfirmacaoSenha('123456', '123456'), null);
    });
  });
}