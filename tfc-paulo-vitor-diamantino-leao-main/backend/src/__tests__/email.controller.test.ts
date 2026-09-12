import { Request, Response } from 'express';
import { QueryResult } from 'pg';
import { pool } from '../database/db';
import bcrypt from 'bcrypt';
import moment from 'moment';
import 'moment-timezone';

// Mock dos módulos
jest.mock('../database/db');
jest.mock('bcrypt');

// Mock do nodemailer ANTES da importação do controller
const mockSendMail = jest.fn();
const mockTransporter = {
  sendMail: mockSendMail
};
jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => mockTransporter)
}));

// Agora importar o controller DEPOIS dos mocks
import { sendPasswordResetEmail, verifyResetToken, resetPasswordWithToken } from '../controllers/email.controller';    
// Mock do moment
const mockMomentInstance = {
  add: jest.fn().mockReturnThis(),
  isAfter: jest.fn(() => false),
  toDate: jest.fn(() => new Date('2024-01-01T16:00:00.000Z')),
  tz: jest.fn().mockReturnThis()
};

// Garantir que todos os métodos retornem o próprio instance para chaining
mockMomentInstance.add.mockReturnValue(mockMomentInstance);
mockMomentInstance.tz.mockReturnValue(mockMomentInstance);

// Mock do moment
jest.mock('moment', () => {
  const mockMoment = jest.fn(() => mockMomentInstance);
  (mockMoment as any).tz = jest.fn(() => mockMomentInstance);
  return mockMoment;
});

// Mock do moment-timezone separadamente
jest.mock('moment-timezone', () => {
  const mockMoment = jest.fn(() => mockMomentInstance);
  (mockMoment as any).tz = jest.fn(() => mockMomentInstance);
  return mockMoment;
});

// Tipagem correta dos mocks
const mockPool = pool as jest.Mocked<typeof pool>;
const mockBcrypt = bcrypt as jest.Mocked<typeof bcrypt>;

// Configurar o mock do pool.query
mockPool.query = jest.fn();

describe('Email Controller', () => {
  let mockReq: Partial<Request>;
  let mockRes: Partial<Response>;
  let mockStatus: jest.Mock;
  let mockJson: jest.Mock;

  beforeEach(() => {
    mockJson = jest.fn();
    mockStatus = jest.fn().mockReturnValue({ json: mockJson });

    mockRes = {
      status: mockStatus,
      json: mockJson
    };

    jest.clearAllMocks();
  });

  describe('sendPasswordResetEmail', () => {
    it('deve enviar email de redefinição com sucesso', async () => {
      mockReq = {
        body: {
          email: 'test@example.com'
        }
      };

      // Mock para encontrar usuário
      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rows: [{ idusuario: 1, nome: 'João' }],
          rowCount: 1,
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para deletar tokens antigos
        .mockResolvedValueOnce({
          rowCount: 0,
          rows: [],
          command: 'DELETE',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para inserir novo token
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [{ id: 1 }],
          command: 'INSERT',
          oid: 0,
          fields: []
        } as QueryResult);

      mockSendMail.mockResolvedValue({ messageId: 'test-id' });

      await sendPasswordResetEmail(mockReq as Request, mockRes as Response);

      expect(mockPool.query).toHaveBeenCalledTimes(3);
      expect(mockSendMail).toHaveBeenCalledWith(expect.objectContaining({
        from: process.env.EMAIL_USER,
        to: 'test@example.com',
        subject: 'Ion - Redefinição de Senha',
        html: expect.stringContaining('João')
      }));
      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        message: 'Email de redefinição enviado com sucesso',
        tokenPreview: expect.any(String)
      });
    });

    it('deve retornar erro quando email não é fornecido', async () => {
      mockReq = {
        body: {}
      };

      await sendPasswordResetEmail(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Email é obrigatório'
      });
    });

    it('deve retornar erro quando email não está cadastrado', async () => {
      mockReq = {
        body: {
          email: 'notfound@example.com'
        }
      };

      (mockPool.query as jest.Mock).mockResolvedValueOnce({
        rows: [],
        rowCount: 0,
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await sendPasswordResetEmail(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(404);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Email não cadastrado'
      });
    });

    it('deve retornar erro interno quando ocorre exceção', async () => {
      mockReq = {
        body: {
          email: 'test@example.com'
        }
      };

      (mockPool.query as jest.Mock).mockRejectedValue(new Error('Database error'));

      await sendPasswordResetEmail(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Erro interno do servidor'
      });
    });
  });

  describe('verifyResetToken', () => {
    it('deve verificar token válido com sucesso', async () => {
      mockReq = {
        body: {
          token: '123456'
        }
      };

      (mockPool.query as jest.Mock).mockResolvedValueOnce({
          rows: [{
            id: 1,
            token: '123456',
            token_expiracao: '2024-01-01T16:00:00.000Z', // 13:00 em São Paulo = 16:00 UTC
            idusuario: 1,
            email: 'test@example.com',
            status: 'ativo',
            tentativas_uso: 0
          }],
          rowCount: 1,
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para incrementar tentativas
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      await verifyResetToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        message: 'Codigo válido',
        idusuario: 1,
        email: 'test@example.com'
      });
    });

    it('deve retornar erro quando token não é fornecido', async () => {
      mockReq = {
        body: {}
      };

      await verifyResetToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Codigo é obrigatório'
      });
    });

    it('deve retornar erro quando token é inválido', async () => {
      mockReq = {
        body: {
          token: 'invalid'
        }
      };

(mockPool.query as jest.Mock).mockResolvedValueOnce({
        rows: [],
        rowCount: 0,
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await verifyResetToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Código Inválido'
      });
    });

    it('deve retornar erro quando token está expirado', async () => {
      mockReq = {
        body: {
          token: '123456'
        }
      };

      // Mock para token expirado - configurar isAfter para retornar true
      mockMomentInstance.isAfter.mockReturnValueOnce(true);

(mockPool.query as jest.Mock).mockResolvedValueOnce({
          rows: [{
            id: 1,
            token: '123456',
            token_expiracao: '2024-01-01T14:00:00.000Z', // 11:00 em São Paulo = 14:00 UTC
            idusuario: 1,
            email: 'test@example.com',
            status: 'ativo',
            tentativas_uso: 0
          }],
          rowCount: 1,
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para atualizar status para expirado
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      await verifyResetToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Codigo expirado'
      });
    });

    // NOVO TESTE: Para cobrir o catch block do verifyResetToken (linhas 137-138)
    it('deve lidar com erro de banco de dados durante verificação', async () => {
      const consoleSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
      
      mockReq = {
        body: {
          token: '123456'
        }
      };

      // Forçar erro no banco de dados
      (mockPool.query as jest.Mock).mockRejectedValueOnce(new Error('Database connection failed'));

      await verifyResetToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Erro interno do servidor'
      });
      expect(consoleSpy).toHaveBeenCalledWith('Erro ao verificar Codigo:', expect.any(Error));
      
      consoleSpy.mockRestore();
    });
  });

  describe('resetPasswordWithToken', () => {
    it('deve redefinir senha com sucesso', async () => {
      mockReq = {
        body: {
          token: '123456',
          newPassword: 'newpass123',
          confirmPassword: 'newpass123'
        }
      };

      // Reset mock para token válido (não expirado)
      const mockMomentInstance = {
        isAfter: jest.fn(() => false)
      };
      (moment as any).tz = jest.fn(() => mockMomentInstance);

      (mockPool.query as jest.Mock).mockResolvedValueOnce({
          rows: [{
            id: 1,
            token: '123456',
            token_expiracao: '2024-01-01T16:00:00.000Z', // 13:00 em São Paulo = 16:00 UTC
            idusuario: 1,
            status: 'ativo'
          }],
          rowCount: 1,
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para atualizar senha
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para marcar token como usado
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

    (mockBcrypt.hash as jest.Mock).mockResolvedValue('hashedpassword123');

      await resetPasswordWithToken(mockReq as Request, mockRes as Response);

      expect(mockBcrypt.hash).toHaveBeenCalledWith('newpass123', 10);
      expect(mockStatus).toHaveBeenCalledWith(200);
      expect(mockJson).toHaveBeenCalledWith({
        message: 'Senha redefinida com sucesso'
      });
    });

    it('deve retornar erro quando campos obrigatórios não são fornecidos', async () => {
      mockReq = {
        body: {
          token: '123456'
          // newPassword e confirmPassword ausentes
        }
      };

      await resetPasswordWithToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Todos os campos são obrigatórios'
      });
    });

    it('deve retornar erro quando senhas não coincidem', async () => {
      mockReq = {
        body: {
          token: '123456',
          newPassword: 'newpass123',
          confirmPassword: 'differentpass'
        }
      };

      await resetPasswordWithToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'As senhas não coincidem'
      });
    });

    it('deve retornar erro quando token não é encontrado', async () => {
      mockReq = {
        body: {
          token: 'invalid',
          newPassword: 'newpass123',
          confirmPassword: 'newpass123'
        }
      };

        (mockPool.query as jest.Mock).mockResolvedValueOnce({
        rows: [],
        rowCount: 0,
        command: 'SELECT',
        oid: 0,
        fields: []
      } as QueryResult);

      await resetPasswordWithToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Codigo não encontrado ou inválido'
      });
    });

    // NOVO TESTE: Para cobrir o branch de token expirado (linhas 170-172)
    it('deve lidar com token expirado durante reset de senha', async () => {
      mockReq = {
        body: {
          token: '123456',
          newPassword: 'newPassword123',
          confirmPassword: 'newPassword123'
        }
      };

      const expiredTokenData = {
        id: 1,
        token: '123456',
        token_expiracao: '2024-01-01T10:00:00.000Z',
        idusuario: 1,
        email: 'test@example.com',
        status: 'ativo'
      };

      // Mock para token encontrado
      (mockPool.query as jest.Mock)
        .mockResolvedValueOnce({
          rows: [expiredTokenData],
          rowCount: 1,
          command: 'SELECT',
          oid: 0,
          fields: []
        } as QueryResult)
        // Mock para atualizar status do token expirado
        .mockResolvedValueOnce({
          rowCount: 1,
          rows: [],
          command: 'UPDATE',
          oid: 0,
          fields: []
        } as QueryResult);

      // Configurar moment para retornar que o token está expirado
      const mockMomentNow = {
        isAfter: jest.fn(() => true) // Token expirado
      };

      const mockMomentExpiration = jest.fn();

      (moment as any)
        .mockReturnValueOnce(mockMomentExpiration) // Para expiração
        .mockReturnValueOnce(mockMomentNow); // Para agora

      mockMomentNow.isAfter.mockReturnValue(true);

      await resetPasswordWithToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(400);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Codigo expirado'
      });
      
      // Verificar se o status foi atualizado para expirado
      expect(mockPool.query).toHaveBeenCalledWith(
        'UPDATE reset_password SET status = $1 WHERE id = $2',
        ['expirado', 1]
      );
    });

    it('deve retornar erro interno quando ocorre exceção', async () => {
      mockReq = {
        body: {
          token: '123456',
          newPassword: 'newpass123',
          confirmPassword: 'newpass123'
        }
      };

      // Reset mock para não expirado antes do erro
      const mockMomentInstance = {
        isAfter: jest.fn(() => false)
      };
      (moment as any).tz = jest.fn(() => mockMomentInstance);
      (mockPool.query as jest.Mock).mockRejectedValue(new Error('Database error'));

      await resetPasswordWithToken(mockReq as Request, mockRes as Response);

      expect(mockStatus).toHaveBeenCalledWith(500);
      expect(mockJson).toHaveBeenCalledWith({
        error: 'Erro interno do servidor'
      });
    });
  });
});