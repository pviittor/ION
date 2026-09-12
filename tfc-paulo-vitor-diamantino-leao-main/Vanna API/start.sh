# #!/bin/bash

# # Caminho para o ambiente virtual Python
# VENV_PATH="./venv"

# # Módulo da aplicação Flask (ex: app:app para o arquivo app.py e instância 'app')
# FLASK_APP_MODULE="app:app"

# # Porta onde o Gunicorn irá escutar
# PORT=5000

# # Verificar se o ambiente virtual existe
# if [ ! -d "$VENV_PATH" ]; then
#   echo "O ambiente virtual não foi encontrado. Criando..."
#   python3 -m venv $VENV_PATH
#   source $VENV_PATH/bin/activate
#   pip install -r requirements.txt
# else
#   echo "Ativando o ambiente virtual..."
#   source $VENV_PATH/bin/activate
# fi

# echo "Iniciando Gunicorn..."
# exec gunicorn --bind 0.0.0.0:$PORT --workers 4 $FLASK_APP_MODULE

source venv/bin/activate
export FLASK_ENV=development
flask run --host=0.0.0.0 --port=5000
