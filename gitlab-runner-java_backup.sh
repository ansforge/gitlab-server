#!/bin/bash
echo "Démarrage du script de sauvegarde de gitlab-runner-java"
#############################################################################
# Nom du script     : gitlab-runner-java-backup.sh
# Auteur            : S.IBN CHARRADA (QM HENIX)
# Date de Création  : 31/05/2023
# Version           : 0.0.2
# Descritpion       : Script permettant la sauvegarde des données (configuration) de Gitlab
#
# Historique des mises à jour :
#-----------+--------+-------------+------------------------------------------------------
#  Version  |   Date   |   Auteur     |  Description
#-----------+--------+-------------+------------------------------------------------------
#  0.0.1    | 31/05/23 | S.IBN CHARRADA    | Initialisation du script
#-----------+--------+-------------+------------------------------------------------------
#  0.0.2    | 21/09/23 | Y.ETRILLARD  | Modification de la casse du path 
#-----------+--------+-------------+------------------------------------------------------

###############################################################################################

. /root/.bash_profile

# Configuration de base: datestamp e.g. YYYYMMDD
DATE=$(date +"%Y%m%d")

# Dossier où sauvegarder les backups
BACKUP_DIR="/var/backup/GITLAB_RUNNER"

# Commande NOMAD
#NOMAD=/usr/local/bin/nomad
NOMAD=$(which nomad)

#Repo PATH To BACKUP DATA in the container
REPO_PATH_CONF=/etc/gitlab-runner
#Archive Name of the backup repo directory
BACKUP_CONF_FILENAME="BACKUP_CONF_GITLAB_RUNNER_${DATE}.tar.gz"


# Nombre de jours à garder les dossiers (seront effacés après X jours)
RETENTION=3

# ---- NE RIEN MODIFIER SOUS CETTE LIGNE ------------------------------------------
#
# Create a new directory into backup directory location for this date
mkdir -p $BACKUP_DIR/$DATE

#  Backup conf
echo "Starting backup GITLAB_RUNNER conf..."

$NOMAD exec -job -task gitlab-runner-java forge-gitlab-runner-java tar -cOzv -C $REPO_PATH_CONF/ . > $BACKUP_DIR/$DATE/$BACKUP_CONF_FILENAME
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -gt 1 ]
then
        echo "Backup GITLAB_RUNNER conf failed with error code : ${BACKUP_RESULT}"
        exit 1
else
        echo "Backup GITLAB_RUNNER conf"
fi

# Remove files older than X days
find $BACKUP_DIR/* -mtime +$RETENTION -exec rm -rf {} \;

echo "GITLAB_RUNNER finished"