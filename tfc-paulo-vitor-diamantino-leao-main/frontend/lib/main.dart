import 'package:flutter/material.dart';
import './screens/user/register_user.dart';
import './screens/user/login_user.dart'; 
import './screens/user/edit_user.dart';
import './screens/permissions/database_permission_screen.dart'; // Novo import

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login e Cadastro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/cadastro': (context) => CadastroUsuarioPage(),
        '/editprofile': (context) => const EditProfileScreen(),
        '/database-permission': (context) => const DatabasePermissionScreen(), // Nova rota
      },
      debugShowCheckedModeBanner: false,
    );
  }
}