import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/validators.dart';

void main() {
  group('Testes Unitários de Login', () {
    
    group('Validação de Email', () {
      test('Deve retornar erro para email vazio', () {
        final resultado = Validators.validarEmail('');
        expect(resultado, 'Por favor, insira seu email');
      });

      test('Deve retornar erro para email null', () {
        final resultado = Validators.validarEmail(null);
        expect(resultado, 'Por favor, insira seu email');
      });

      test('Deve retornar erro para email inválido', () {
        final resultado = Validators.validarEmail('email_invalido');
        expect(resultado, 'Por favor, insira um email válido');
      });

      test('Deve retornar erro para email sem @', () {
        final resultado = Validators.validarEmail('emailsemarroba.com');
        expect(resultado, 'Por favor, insira um email válido');
      });

      test('Deve retornar erro para email sem domínio', () {
        final resultado = Validators.validarEmail('email@');
        expect(resultado, 'Por favor, insira um email válido');
      });

      test('Deve aceitar email válido', () {
        final resultado = Validators.validarEmail('teste@email.com');
        expect(resultado, null);
      });

      test('Deve aceitar email com subdomínio', () {
        final resultado = Validators.validarEmail('usuario@mail.empresa.com.br');
        expect(resultado, null);
      });
    });

    group('Validação de Senha', () {
      test('Deve retornar erro para senha vazia', () {
        final resultado = Validators.validarSenha('');
        expect(resultado, 'Por favor, insira sua senha');
      });

      test('Deve retornar erro para senha null', () {
        final resultado = Validators.validarSenha(null);
        expect(resultado, 'Por favor, insira sua senha');
      });

      test('Deve retornar erro para senha muito curta', () {
        final resultado = Validators.validarSenha('123');
        expect(resultado, 'A senha deve ter pelo menos 6 caracteres');
      });

      test('Deve retornar erro para senha com 5 caracteres', () {
        final resultado = Validators.validarSenha('12345');
        expect(resultado, 'A senha deve ter pelo menos 6 caracteres');
      });

      test('Deve aceitar senha com 6 caracteres', () {
        final resultado = Validators.validarSenha('123456');
        expect(resultado, null);
      });

      test('Deve aceitar senha longa', () {
        final resultado = Validators.validarSenha('senhamuitorande123');
        expect(resultado, null);
      });
    });
  });
}