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
#  0.0.2    | 06/03/23 | E.RIEGEL     | Ajout de la sauvegarde de /etc/gitlab
#-----------+--------+-------------+------------------------------------------------------
#  0.0.3    | 21/09/23 | Y.ETRILLARD  | Modification de la casse du path 
#-----------+--------+-------------+------------------------------------------------------
#  1.0.0    | 28/08/24 | M. FAUREL    | Modification de la casse du backup_dir 
#-----------+--------+-------------+------------------------------------------------------
#
###############################################################################################

. /root/.bash_profile

# Configuration de base: datestamp e.g. YYYYMMDD
DATE=$(date +"%Y%m%d")
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Dossier où sauvegarder les backups
BACKUP_DIR="/var/backup/gitlab"

# Commande NOMAD
#NOMAD=/usr/local/bin/nomad
NOMAD=$(which nomad)

#Repo PATH To BACKUP DATA in the container
REPO_PATH_DATA=/var/opt
#Archive Name of the backup repo directory
BACKUP_REPO_FILENAME="BACKUP_DATA_GITLAB_${DATE}.tar.gz"

#Repo PATH To BACKUP DATA in the container
REPO_PATH_CONF=/etc
#Archive Name of the backup repo directory
BACKUP_CONF_FILENAME="BACKUP_CONF_GITLAB_${DATE}.tar.gz"


# Nombre de jours à garder les dossiers (seront effacés après X jours)
RETENTION=10

# ---- NE RIEN MODIFIER SOUS CETTE LIGNE ------------------------------------------
#
# Create a new directory into backup directory location for this date
mkdir -p $BACKUP_DIR/$DATE

# Backup repos
echo "${TIMESTAMP} Starting backup gitlab data..."

$NOMAD exec -job -task gitlab forge-gitlab tar -cOzv -C $REPO_PATH_DATA gitlab > $BACKUP_DIR/$DATE/$BACKUP_REPO_FILENAME
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -gt 1 ]
then
        echo "${TIMESTAMP} Backup GitLab Data failed with error code : ${BACKUP_RESULT}"
        exit 1
else
        echo "${TIMESTAMP} Backup GitLab Data done"
fi

# Backup conf
echo "${TIMESTAMP} Starting backup gitlab conf..."

$NOMAD exec -job -task gitlab forge-gitlab tar -cOzv -C $REPO_PATH_CONF gitlab > $BACKUP_DIR/$DATE/$BACKUP_CONF_FILENAME
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -gt 1 ]
then
        echo "${TIMESTAMP} Backup GitLab conf failed with error code : ${BACKUP_RESULT}"
        exit 1
else
        echo "${TIMESTAMP} Backup GitLab Conf done"
fi

# Remove files older than X days
find $BACKUP_DIR/* -mtime +$RETENTION -exec rm -rf {} \;

echo "${TIMESTAMP} Backup Gitlab finished"

