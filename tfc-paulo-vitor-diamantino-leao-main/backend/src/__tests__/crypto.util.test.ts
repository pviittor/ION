import { encrypt, decrypt } from '../utils/crypto.util';

describe('Crypto Util', () => {
  // Teste para cobrir o branch da ENCRYPTION_KEY
  describe('ENCRYPTION_KEY fallback', () => {
    it('deve usar a chave padrão quando ENCRYPTION_KEY não estiver definida', () => {
      // Salvar o valor original
      const originalKey = process.env.ENCRYPTION_KEY;
      
      // Remover a variável de ambiente
      delete process.env.ENCRYPTION_KEY;
      
      // Recarregar o módulo para testar o fallback
      jest.resetModules();
      const { encrypt: encryptTest } = require('../utils/crypto.util');
      
      const texto = 'Teste fallback';
      const resultado = encryptTest(texto);
      
      expect(resultado).toBeDefined();
      expect(resultado).toContain(':');
      
      // Restaurar o valor original
      process.env.ENCRYPTION_KEY = originalKey;
    });
  });

  describe('encrypt', () => {
    it('deve criptografar um texto simples', () => {
      const texto = 'Hello World';
      const textoCriptografado = encrypt(texto);
      
      expect(textoCriptografado).toBeDefined();
      expect(textoCriptografado).not.toBe(texto);
      expect(textoCriptografado).toContain(':'); // Formato: iv:encrypted
    });

    it('deve gerar resultados diferentes para o mesmo texto (devido ao IV aleatório)', () => {
      const texto = 'Mesmo texto';
      const criptografado1 = encrypt(texto);
      const criptografado2 = encrypt(texto);
      
      expect(criptografado1).not.toBe(criptografado2);
    });

    it('deve criptografar textos vazios', () => {
      const textoVazio = '';
      const textoCriptografado = encrypt(textoVazio);
      
      expect(textoCriptografado).toBeDefined();
      expect(textoCriptografado).toContain(':');
    });

    it('deve criptografar textos com caracteres especiais', () => {
      const textoEspecial = 'Texto com acentos: ção, ã, é, ü e símbolos: @#$%';
      const textoCriptografado = encrypt(textoEspecial);
      
      expect(textoCriptografado).toBeDefined();
      expect(textoCriptografado).not.toBe(textoEspecial);
    });
  });

  describe('decrypt', () => {
    it('deve descriptografar um texto criptografado', () => {
      const textoOriginal = 'Texto para teste';
      const textoCriptografado = encrypt(textoOriginal);
      const textoDescriptografado = decrypt(textoCriptografado);
      
      expect(textoDescriptografado).toBe(textoOriginal);
    });

    it('deve descriptografar textos vazios', () => {
      const textoVazio = '';
      const textoCriptografado = encrypt(textoVazio);
      const textoDescriptografado = decrypt(textoCriptografado);
      
      expect(textoDescriptografado).toBe(textoVazio);
    });

    it('deve descriptografar textos com caracteres especiais', () => {
      const textoEspecial = 'Dados sensíveis: CPF 123.456.789-00, Email: user@test.com';
      const textoCriptografado = encrypt(textoEspecial);
      const textoDescriptografado = decrypt(textoCriptografado);
      
      expect(textoDescriptografado).toBe(textoEspecial);
    });

    it('deve falhar ao tentar descriptografar texto inválido', () => {
      const textoInvalido = 'texto-nao-criptografado';
      
      expect(() => {
        decrypt(textoInvalido);
      }).toThrow();
    });

    it('deve falhar ao tentar descriptografar com formato inválido', () => {
      const formatoInvalido = 'sem-dois-pontos';
      
      expect(() => {
        decrypt(formatoInvalido);
      }).toThrow();
    });
  });

  describe('Integração encrypt/decrypt', () => {
    it('deve manter a integridade dos dados em múltiplas operações', () => {
      const dadosOriginais = [
        'Texto simples',
        'Dados com números: 12345',
        'Símbolos especiais: !@#$%^&*()',
        'Texto longo '.repeat(100),
        ''
      ];
      
      dadosOriginais.forEach(dado => {
        const criptografado = encrypt(dado);
        const descriptografado = decrypt(criptografado);
        expect(descriptografado).toBe(dado);
      });
    });

    it('deve funcionar com dados JSON', () => {
      const objetoOriginal = {
        id: 123,
        nome: 'João Silva',
        email: 'joao@test.com',
        dados: {
          telefone: '11999999999',
          endereco: 'Rua das Flores, 123'
        }
      };
      
      const jsonString = JSON.stringify(objetoOriginal);
      const criptografado = encrypt(jsonString);
      const descriptografado = decrypt(criptografado);
      const objetoRecuperado = JSON.parse(descriptografado);
      
      expect(objetoRecuperado).toEqual(objetoOriginal);
    });
  });

  describe('Segurança', () => {
    it('deve usar IV (Initialization Vector) diferente a cada criptografia', () => {
      const texto = 'Teste de segurança';
      const resultados = new Set();
      
      // Gerar 10 criptografias do mesmo texto
      for (let i = 0; i < 10; i++) {
        const criptografado = encrypt(texto);
        const iv = criptografado.split(':')[0];
        resultados.add(iv);
      }
      
      // Todos os IVs devem ser únicos
      expect(resultados.size).toBe(10);
    });

    it('deve gerar hash consistente da chave', () => {
      // Teste indireto: mesmo texto deve ser descriptografável
      const texto = 'Teste de consistência';
      const criptografado1 = encrypt(texto);
      const criptografado2 = encrypt(texto);
      
      // Ambos devem ser descriptografáveis
      expect(decrypt(criptografado1)).toBe(texto);
      expect(decrypt(criptografado2)).toBe(texto);
    });
  });
});