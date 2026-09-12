import { Request, Response } from 'express';
import { login } from '../controllers/auth.controller';
import { pool } from '../database/db';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { QueryResult } from 'pg';

// Mock dos módulos
jest.mock('../database/db');
jest.mock('bcrypt');
jest.mock('jsonwebtoken');

// Tipagem correta dos mocks
const mockPool = pool as jest.Mocked<typeof pool>;
const mockBcrypt = bcrypt as jest.Mocked<typeof bcrypt>;
const mockJwt = jwt as jest.Mocked<typeof jwt>;

// Configurar o mock do pool.query
mockPool.query = jest.fn();

describe('Auth Controller', () => {
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
    // Limpar mocks anteriores
    jest.clearAllMocks();
  });

  describe('login', () => {
    it('deve fazer login com sucesso', async () => {
      const mockUser = {
        idusuario: 1,
        email: 'test@test.com',
        senha: 'hashedPassword',
        nome: 'Test User'
      };

      mockReq = {
        body: {
          email: 'test@test.com',
          senha: 'password123'
        }
      };

      // Configurar mocks para login com sucesso
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [mockUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);
      
      (mockBcrypt.compare as jest.Mock).mockResolvedValue(true);
      (mockJwt.sign as jest.Mock).mockReturnValue('mock-token');

      await login(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Login realizado com sucesso',
        token: 'mock-token',
        usuario: {
          id: 1,
          nome: 'Test User',
          email: 'test@test.com'
        }
      });
    });

    it('deve retornar erro quando usuário não existe', async () => {
      mockReq = {
        body: {
          email: 'nonexistent@test.com',
          senha: 'password123'
        }
      };

      // Configurar mock para usuário não encontrado
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 0,
        rows: [],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);
    
      await login(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Usuário não encontrado'
      });
    });

    it('deve retornar erro quando senha está incorreta', async () => {
      const mockUser = {
        idusuario: 1,
        email: 'test@test.com',
        senha: 'hashedPassword',
        nome: 'Test User'
      };

      mockReq = {
        body: {
          email: 'test@test.com',
          senha: 'wrongpassword'
        }
      };

      // Configurar mocks para senha incorreta
      (mockPool.query as jest.Mock).mockResolvedValue({
        rowCount: 1,
        rows: [mockUser],
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);
      
      (mockBcrypt.compare as jest.Mock).mockResolvedValue(false);

      await login(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(401);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Senha incorreta'
      });
    });

    it('deve tratar erros do banco de dados', async () => {
      mockReq = {
        body: {
          email: 'test@test.com',
          senha: 'password123'
        }
      };
    
      // Configurar mock para erro do banco de dados
      (mockPool.query as jest.Mock).mockRejectedValue(new Error('Database error'));
    
      await login(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        mensagem: 'Erro interno do servidor'
      });
    });
  });
});