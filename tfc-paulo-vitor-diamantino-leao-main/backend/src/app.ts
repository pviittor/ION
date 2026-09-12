import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth.routes';
import { buscarPorUsuario, criar } from './controllers/userCredentials.controller';

// Configurar dotenv
dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// Usar _ para parâmetros não utilizados
app.use((req, _res, next) => {
  console.log(`ROTA: ${req.method} ${req.url}`);
  console.log('BODY:', req.body);
  next();
});

// Usar _ para parâmetros não utilizados
app.get('/', (_req, res) => {
  res.send('Hello World!');
});

app.use('/api', authRoutes); 
app.use('/api', criar);
app.use('/api', buscarPorUsuario);

export default app;

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Servidor rodando na porta ${PORT}`);
});
