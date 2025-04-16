#----------------------------
##### alias fd ###
#----------------------------

# Couleur du user@host
PS1='\[\e[32m\]\u@\h\[\e[m\]:\[\e[34m\]\w\[\e[m\]\$ '

# Charger le bash perso avec les alias
if [ -f ~/.bash_perso_fd ]; then
   source ~/.bash_perso_fd
fi
# Charger le bash perso avec les alias
if [ -f ~/.bash_perso_fd ]; then
   source ~/.bash_aliases
fi


export PATH="$HOME/script_perso:$PATH"


# Ajouter /script_perso au PATH globalement si ce n'est pas déjà fait
if ! grep -Fxq 'export PATH="/script_perso:$PATH"' /etc/profile; then
   echo 'export PATH="/script_perso:$PATH"' | sudo tee -a /etc/profile
fi

# Alias de navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"          # Aller rapidement au repertoire personnel
alias c="clear"         # Effacer l'ecran
alias ll="ls -lahF"     # Liste detaillee avec des tailles lisibles
alias la="ls -A"        # Liste tous les fichiers, y compris les caches
alias l="ls -CF"        # Liste basique
alias home="cd ~"       # Aller au repertoire personnel

# Alias pour lister les fichiers
alias ls="ls --color=auto"  # Colorer les fichiers et dossiers
alias lsd="ls -l | grep '^d'"  # Lister uniquement les repertoires
alias lt="ls -ltr"  # Liste les fichiers tries par date de modification (le plus recent a la fin)


# Alias pour les operations sur les fichiers
alias cp="cp -i"  # Copier avec confirmation (evite d'ecraser accidentellement des fichiers)
alias mv="mv -i"  # Deplacer avec confirmation
alias rm="rm -i"  # Supprimer avec confirmation
alias mkdir="mkdir -pv"  # Creer des repertoires de maniere recursive avec confirmation

# Alias pour les archives
alias untar="tar -xvf"  # Decompresser des fichiers tar
alias tgz="tar -czvf"  # Creer une archive tar.gz
alias untgz="tar -xzvf"  # Decompresser une archive tar.gz
alias zipf="zip -r"  # Creer un fichier ZIP
alias unzipf="unzip"  # Extraire un fichier ZIP

# Alias pour grep
alias grep="grep --color=auto"  # Colorer les resultats des recherches
alias findtext="grep -rnw ."  # Rechercher du texte dans les fichiers du repertoire courant

# Alias pour la gestion des paquets (exemples pour Debian/Ubuntu)
alias update="sudo apt update && sudo apt upgrade"  # Mettre a jour le systeme
alias install="sudo apt install"  # Installer un paquet
alias remove="sudo apt remove"  # Supprimer un paquet
alias search="apt search"  # Rechercher un paquet

# Alias pour Git
alias gts="git status"
alias gck="git checkout"
alias ga="git add"
alias gaa="git add ."
alias gcmsg="git commit -m"
alias gps="git push"
alias gpl="git pull"
alias glog="git log --oneline --graph --all --decorate"
alias gbr="git branch"

# Alias pour le reseau
alias myip="curl ifconfig.me"  # Obtenir l adresse IP publique
alias ports="netstat -tulanp"  # Afficher les ports ouverts
alias ping="ping -c 5"  # Limiter le nombre de pings a 5

# Alias pour la gestion des processus
alias psg="ps aux | grep -v grep | grep -i -e VSZ -e"  # Rechercher un processus
alias kill9="kill -9"  # Forcer l arret d un processus
alias meminfo="free -m -l -t"  # Afficher les informations sur la memoire



# Alias pour gérer les environnements virtuels Python
alias mkvenv="virtualenv venv"  # Créer un nouvel environnement virtuel
alias activ="./venv/Script/activate"  # Activer un environnement virtuel (venv)
alias deactvenv="deactivate"  # Désactiver l'environnement virtuel actif
alias lsvenv="lsvirtualenv"  # Lister tous les environnements virtuels (si virtualenvwrapper est installé)
alias rmvenv="rm -rf ./venv"  # Supprimer un environnement virtuel (venv)
alias freeze="pip freeze > requirements.txt"  # Exporter les dépendances dans un fichier requirements.txt
alias installrequirement="pip install -r requirements.txt"  # Installer les dépendances depuis un fichier requirements.txt



# Accés aux repertoires AJC
alias mnt="cd /mnt/c/AJC_formation"
alias mnt2="cd /mnt/c/AJC_projets"

# Charger la configuration
alias reload="source ~/.bashrc"