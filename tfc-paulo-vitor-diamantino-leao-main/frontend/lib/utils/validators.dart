class Validators {
  // Validação de Nome
  static String? validarNome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nome é obrigatório';
    }
    
    String nomeFormatado = formatarNome(value);
    
    if (nomeFormatado.length < 2) {
      return 'Nome deve ter pelo menos 2 caracteres';
    }
    
    if (nomeFormatado.length > 50) {
      return 'Nome deve ter no máximo 50 caracteres';
    }
    
    // Verificar números primeiro
    if (RegExp(r'\d').hasMatch(nomeFormatado)) {
      return 'Nome não pode conter números';
    }
    
    // Depois verificar outros caracteres especiais
    RegExp nomeRegex = RegExp(r'^[a-zA-ZÀ-ÿ\s]+$');
    if (!nomeRegex.hasMatch(nomeFormatado)) {
      return 'Nome deve conter apenas letras';
    }
    
    return null;
  }

  // Validação de Sobrenome
  static String? validarSobrenome(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Sobrenome é obrigatório';
    }
    
    String sobrenomeFormatado = formatarNome(value);
    
    if (sobrenomeFormatado.length < 2) {
      return 'Sobrenome deve ter pelo menos 2 caracteres';
    }
    
    if (sobrenomeFormatado.length > 50) {
      return 'Sobrenome deve ter no máximo 50 caracteres';
    }
    
    // Verificar números primeiro
    if (RegExp(r'\d').hasMatch(sobrenomeFormatado)) {
      return 'Sobrenome não pode conter números';
    }
    
    // Depois verificar outros caracteres especiais
    RegExp sobrenomeRegex = RegExp(r'^[a-zA-ZÀ-ÿ\s]+$');
    if (!sobrenomeRegex.hasMatch(sobrenomeFormatado)) {
      return 'Sobrenome deve conter apenas letras';
    }
    
    return null;
  }

  // Validação de Telefone
  static String? validarTelefone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefone é obrigatório';
    }
    
    String telefoneNumeros = value.replaceAll(RegExp(r'\D'), '');
    
    if (telefoneNumeros.length < 10) {
      return 'Telefone deve ter pelo menos 10 dígitos';
    }
    
    if (telefoneNumeros.length > 11) {
      return 'Telefone deve ter no máximo 11 dígitos';
    }
    
    if (telefoneNumeros.length == 11 && !telefoneNumeros.substring(2, 3).startsWith('9')) {
      return 'Número de celular deve começar com 9';
    }
    
    if (telefoneNumeros.length >= 2) {
      int codigoArea = int.tryParse(telefoneNumeros.substring(0, 2)) ?? 0;
      if (codigoArea < 11 || codigoArea > 99) {
        return 'Código de área inválido';
      }
    }
    
    return null;
  }

  // Validação de Email
  static String? validarEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, insira seu email';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Por favor, insira um email válido';
    }
    return null;
  }

  // Validação de Senha
  static String? validarSenha(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor, insira sua senha';
    }
    if (value.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }

  // Validação de Confirmação de Senha
  static String? validarConfirmacaoSenha(String? value, String senha) {
    if (value == null || value.isEmpty) {
      return 'Confirme sua senha';
    }
    if (value != senha) {
      return 'As senhas não coincidem';
    }
    return null;
  }

  // Formatadores
  static String formatarNome(String nome) {
    return nome.trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  static String formatarTelefone(String telefone) {
    String numeros = telefone.replaceAll(RegExp(r'\D'), '');
    
    if (numeros.length == 10) {
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 6)}-${numeros.substring(6)}';
    } else if (numeros.length == 11) {
      return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 7)}-${numeros.substring(7)}';
    }
    
    return telefone;
  }
}