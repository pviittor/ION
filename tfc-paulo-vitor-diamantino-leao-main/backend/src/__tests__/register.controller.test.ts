import { Request, Response } from 'express';
import { register } from '../controllers/register.controller';
import { pool } from '../database/db';
import bcrypt from 'bcrypt';

// Mock dos módulos
jest.mock('../database/db');
jest.mock('bcrypt');

// Tipagem correta dos mocks
const mockPool = pool as jest.Mocked<typeof pool>;
const mockBcrypt = bcrypt as jest.Mocked<typeof bcrypt>;

// Configurar o mock do pool.query
mockPool.query = jest.fn();

describe('Register Controller', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockJson: jest.Mock;
  let mockStatus: jest.Mock;

  beforeEach(() => {
    mockJson = jest.fn();
    mockStatus = jest.fn().mockReturnValue({ json: mockJson });
    mockRes = {
      status: mockStatus,
      json: mockJson
    };
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('deve cadastrar usuário com sucesso', async () => {
      mockReq = {
        body: {
          nome: 'João',
          sobrenome: 'Silva',
          email: 'joao@test.com',
          telefone: '11999999999',
          senha: 'password123'
        }
      };

      // Mock para verificar se email já existe
      (mockPool.query as jest.MockedFunction<any>)
        .mockResolvedValueOnce({
          rowCount: 0,
          rows: []
        })
        .mockResolvedValueOnce({
          rows: [{ idusuario: 1 }]
        });

      (mockBcrypt.hash as jest.MockedFunction<any>).mockResolvedValue('hashedPassword');

      await register(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledTimes(2);
      expect(mockBcrypt.hash).toHaveBeenCalledWith('password123', 10);
      expect(mockStatus).toHaveBeenCalledWith(201);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Usuário cadastrado com sucesso',
        idusuario: 1
      });
    });

    it('deve retornar erro quando campos obrigatórios estão faltando', async () => {
      const testCases = [
        { nome: 'João' },
        { nome: 'João', sobrenome: 'Silva' },
        { nome: 'João', sobrenome: 'Silva', email: 'joao@test.com' },
        { nome: 'João', sobrenome: 'Silva', email: 'joao@test.com', telefone: '11999999999' },
        { sobrenome: 'Silva', email: 'joao@test.com', telefone: '11999999999', senha: 'password123' }
      ];

      for (const testCase of testCases) {
        mockReq = {
          body: testCase
        };

        await register(mockReq as Request, mockRes as Response);

        expect(mockStatus).toHaveBeenCalledWith(400);
        expect(mockJson).toHaveBeenCalledWith({
          mensagem: 'Todos os campos são obrigatórios.'
        });
      }
    });

    it('deve retornar erro quando email já está cadastrado', async () => {
      mockReq = {
        body: {
          nome: 'João',
          sobrenome: 'Silva',
          email: 'joao@test.com',
          telefone: '11999999999',
          senha: 'password123'
        }
      };

      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({
        rowCount: 1,
        rows: [{ email: 'joao@test.com' }]
      });

      await register(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledWith(
        'SELECT 1 FROM usuarios WHERE email = $1',
        ['joao@test.com']
      );
      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Email já cadastrado.'
      });
    });

    it('deve retornar erro quando falha ao criptografar senha', async () => {
      mockReq = {
        body: {
          nome: 'João',
          sobrenome: 'Silva',
          email: 'joao@test.com',
          telefone: '11999999999',
          senha: 'password123'
        }
      };

      (mockPool.query as jest.MockedFunction<any>).mockResolvedValueOnce({
        rowCount: 0,
        rows: []
      });

(mockBcrypt.hash as jest.MockedFunction<any>).mockRejectedValue(new Error('Encryption failed'));

      await register(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno do servidor.'
      });
    });

    it('deve retornar erro quando falha ao inserir no banco de dados', async () => {
      mockReq = {
        body: {
          nome: 'João',
          sobrenome: 'Silva',
          email: 'joao@test.com',
          telefone: '11999999999',
          senha: 'password123'
        }
      };

      (mockPool.query as jest.MockedFunction<any>)
        .mockResolvedValueOnce({
          rowCount: 0,
          rows: []
        })
        .mockRejectedValueOnce(new Error('Database error'));

      (mockBcrypt.hash as jest.MockedFunction<any>).mockResolvedValue('hashedPassword');

      await register(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno do servidor.'
      });
    });

    it('deve retornar erro quando falha ao verificar email existente', async () => {
      mockReq = {
        body: {
          nome: 'João',
          sobrenome: 'Silva',
          email: 'joao@test.com',
          telefone: '11999999999',
          senha: 'password123'
        }
      };

      (mockPool.query as jest.MockedFunction<any>).mockRejectedValueOnce(new Error('Database error'));

      await register(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno do servidor.'
      });
    });
  });
});