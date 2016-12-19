Script pessoal para subir uma nova máquina na Digital Ocean com um novo site WordPress instalado via EasyEngine

Depende de:
- doctl (linha de comando Digital Ocean)

Feito em macOS. Talvez funcione em outros nix.

Como usar
---
* Torne executável: chmod a+x wp-ee-do.sh
* Altere as variáveis dentro do arquivo (Nome e Email)
* Rode: ./wp-ee-do.sh [nome_droplet] [url_site]
