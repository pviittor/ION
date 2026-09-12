"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const crypto_util_1 = require("../utils/crypto.util");
describe('Crypto Util', () => {
    describe('encrypt', () => {
        it('deve criptografar um texto simples', () => {
            const texto = 'Hello World';
            const textoCriptografado = (0, crypto_util_1.encrypt)(texto);
            expect(textoCriptografado).toBeDefined();
            expect(textoCriptografado).not.toBe(texto);
            expect(textoCriptografado).toContain(':'); // Formato: iv:encrypted
        });
        it('deve gerar resultados diferentes para o mesmo texto (devido ao IV aleatório)', () => {
            const texto = 'Mesmo texto';
            const criptografado1 = (0, crypto_util_1.encrypt)(texto);
            const criptografado2 = (0, crypto_util_1.encrypt)(texto);
            expect(criptografado1).not.toBe(criptografado2);
        });
        it('deve criptografar textos vazios', () => {
            const textoVazio = '';
            const textoCriptografado = (0, crypto_util_1.encrypt)(textoVazio);
            expect(textoCriptografado).toBeDefined();
            expect(textoCriptografado).toContain(':');
        });
        it('deve criptografar textos com caracteres especiais', () => {
            const textoEspecial = 'Texto com acentos: ção, ã, é, ü e símbolos: @#$%';
            const textoCriptografado = (0, crypto_util_1.encrypt)(textoEspecial);
            expect(textoCriptografado).toBeDefined();
            expect(textoCriptografado).not.toBe(textoEspecial);
        });
    });
    describe('decrypt', () => {
        it('deve descriptografar um texto criptografado', () => {
            const textoOriginal = 'Texto para teste';
            const textoCriptografado = (0, crypto_util_1.encrypt)(textoOriginal);
            const textoDescriptografado = (0, crypto_util_1.decrypt)(textoCriptografado);
            expect(textoDescriptografado).toBe(textoOriginal);
        });
        it('deve descriptografar textos vazios', () => {
            const textoVazio = '';
            const textoCriptografado = (0, crypto_util_1.encrypt)(textoVazio);
            const textoDescriptografado = (0, crypto_util_1.decrypt)(textoCriptografado);
            expect(textoDescriptografado).toBe(textoVazio);
        });
        it('deve descriptografar textos com caracteres especiais', () => {
            const textoEspecial = 'Dados sensíveis: CPF 123.456.789-00, Email: user@test.com';
            const textoCriptografado = (0, crypto_util_1.encrypt)(textoEspecial);
            const textoDescriptografado = (0, crypto_util_1.decrypt)(textoCriptografado);
            expect(textoDescriptografado).toBe(textoEspecial);
        });
        it('deve falhar ao tentar descriptografar texto inválido', () => {
            const textoInvalido = 'texto-nao-criptografado';
            expect(() => {
                (0, crypto_util_1.decrypt)(textoInvalido);
            }).toThrow();
        });
        it('deve falhar ao tentar descriptografar com formato inválido', () => {
            const formatoInvalido = 'sem-dois-pontos';
            expect(() => {
                (0, crypto_util_1.decrypt)(formatoInvalido);
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
                const criptografado = (0, crypto_util_1.encrypt)(dado);
                const descriptografado = (0, crypto_util_1.decrypt)(criptografado);
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
            const criptografado = (0, crypto_util_1.encrypt)(jsonString);
            const descriptografado = (0, crypto_util_1.decrypt)(criptografado);
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
                const criptografado = (0, crypto_util_1.encrypt)(texto);
                const iv = criptografado.split(':')[0];
                resultados.add(iv);
            }
            // Todos os IVs devem ser únicos
            expect(resultados.size).toBe(10);
        });
        it('deve gerar hash consistente da chave', () => {
            // Teste indireto: mesmo texto deve ser descriptografável
            const texto = 'Teste de consistência';
            const criptografado1 = (0, crypto_util_1.encrypt)(texto);
            const criptografado2 = (0, crypto_util_1.encrypt)(texto);
            // Ambos devem ser descriptografáveis
            expect((0, crypto_util_1.decrypt)(criptografado1)).toBe(texto);
            expect((0, crypto_util_1.decrypt)(criptografado2)).toBe(texto);
        });
    });
});
