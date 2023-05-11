#!/bin/bash
echo "Démarrage du script de sauvegarde de GitLab"
#############################################################################
# Nom du script     : gitlab-backup.sh
# Auteur            : E.RIEGEL (QM HENIX)
# Date de Création  : 22/02/2023
# Version           : 1.0.0
# Descritpion       : Script permettant la sauvegarde des données de Gitlab
#
# Historique des mises à jour :
#-----------+--------+-------------+------------------------------------------------------
#  Version  |   Date   |   Auteur     |  Description
#-----------+--------+-------------+------------------------------------------------------
#  0.0.1    | 22/02/23 | E.RIEGEL     | Initialisation du script
#-----------+--------+-------------+------------------------------------------------------
#
###############################################################################################

. /root/.bash_profile

# Configuration de base: datestamp e.g. YYYYMMDD
DATE=$(date +"%Y%m%d")

# Dossier où sauvegarder les backups
BACKUP_DIR="/var/BACKUP/GITLAB"

# Commande NOMAD
#NOMAD=/usr/local/bin/nomad
NOMAD=$(which nomad)

#Repo PATH To BACKUP in the container
REPO_PATH=/var/opt
#Archive Name of the backup repo directory
BACKUP_REPO_FILENAME="BACKUP_DATA_GITLAB_${DATE}.tar.gz"


# Nombre de jours à garder les dossiers (seront effacés après X jours)
RETENTION=3

# ---- NE RIEN MODIFIER SOUS CETTE LIGNE ------------------------------------------
#
# Create a new directory into backup directory location for this date
mkdir -p $BACKUP_DIR/$DATE

# Backup repos
echo "Starting backup gitlab data..."

$NOMAD exec -job -task gitlab forge-gitlab tar -cOzv -C $REPO_PATH gitlab > $BACKUP_DIR/$DATE/$BACKUP_REPO_FILENAME
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -gt 1 ]
then
        echo "Backup GitLab failed with error code : ${BACKUP_RESULT}"
        exit 1
else
        echo "Backup GitLab done"
fi

# Remove files older than X days
find $BACKUP_DIR/* -mtime +$RETENTION -exec rm -rf {} \;

echo "Backup Gitlab finished"
