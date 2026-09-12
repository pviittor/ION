import { Router } from 'express';
import { login } from '../controllers/auth.controller';
import { register } from '../controllers/register.controller';
import { updateUser } from '../controllers/updateUser.controller';
import { deleteUser } from '../controllers/deleteUser.controller';
import { getUser, getUserByPhone } from '../controllers/getUser.controller';
import { criar, buscarPorUsuario, atualizarVanna } from '../controllers/userCredentials.controller';
import { sendPasswordResetEmail, verifyResetToken, resetPasswordWithToken } from '../controllers/email.controller';

const router = Router();

router.post('/cadastro', register);

router.post('/login', login);

router.put('/usuarios/:idusuario', updateUser);

router.delete('/usuarios/:idusuario', deleteUser);

router.get('/usuarios/:idusuario', getUser);

router.get('/usuario/telefone/:telefone', getUserByPhone);

router.post('/credenciais', criar);

router.get('/credenciais/:idusuario', buscarPorUsuario);

router.put('/credenciais/:idusuario', atualizarVanna);

router.post('/password-reset/send-email', sendPasswordResetEmail);
router.post('/password-reset/verify-token', verifyResetToken);
router.post('/password-reset/reset-password', resetPasswordWithToken);

export default router;
