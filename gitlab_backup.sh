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
#  1.0.1    | 06/11/24 | M. FAUREL   | Modification du timestamp
#-----------+--------+-------------+------------------------------------------------------
#
###############################################################################################

. /root/.bash_profile

# Configuration de base: datestamp e.g. YYYYMMDD
DATE=$(date +"%Y%m%d")

# Dossier où sauvegarder les backups
BACKUP_DIR="/var/backup/gitlab"

# Commande NOMAD
#NOMAD=/usr/local/bin/nomad
NOMAD=$(which nomad)

#Repo PATH To BACKUP DATA in the container
REPO_PATH_DATA=/var/opt
#Archive Name of the backup repo directory
BACKUP_REPO_FILENAME="backup_data_gitlab_${DATE}.tar.gz"

#Repo PATH To BACKUP DATA in the container
REPO_PATH_CONF=/etc
#Archive Name of the backup repo directory
BACKUP_CONF_FILENAME="backup_conf_gitlab_${DATE}.tar.gz"


# Nombre de jours à garder les dossiers (seront effacés après X jours)
RETENTION=10

# ---- NE RIEN MODIFIER SOUS CETTE LIGNE ------------------------------------------
#
# Create a new directory into backup directory location for this date
mkdir -p $BACKUP_DIR/$DATE

# Backup repos
echo "$(date +"%Y-%m-%d %H:%M:%S") Starting backup gitlab data..." >> $BACKUP_DIR/gitlab_backup-cron-`date +\%F`.log

$NOMAD exec -job -task gitlab forge-gitlab tar -cOzv -C $REPO_PATH_DATA gitlab > $BACKUP_DIR/$DATE/$BACKUP_REPO_FILENAME
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -gt 1 ]
then
        echo "$(date +"%Y-%m-%d %H:%M:%S") Backup GitLab Data failed with error code : ${BACKUP_RESULT}" >> $BACKUP_DIR/gitlab_backup-cron-`date +\%F`.log
        exit 1
else
        echo "$(date +"%Y-%m-%d %H:%M:%S") Backup GitLab Data done" >> $BACKUP_DIR/gitlab_backup-cron-`date +\%F`.log
fi

# Backup conf
echo "$(date +"%Y-%m-%d %H:%M:%S") Starting backup gitlab conf..." >> $BACKUP_DIR/gitlab_backup-cron-`date +\%F`.log

$NOMAD exec -job -task gitlab forge-gitlab tar -cOzv -C $REPO_PATH_CONF gitlab > $BACKUP_DIR/$DATE/$BACKUP_CONF_FILENAME
BACKUP_RESULT=$?
if [ $BACKUP_RESULT -gt 1 ]
then
        echo "$(date +"%Y-%m-%d %H:%M:%S") Backup GitLab Conf failed with error code : ${BACKUP_RESULT}" >> $BACKUP_DIR/gitlab_backup-cron-`date +\%F`.log
        exit 1
else
        echo "$(date +"%Y-%m-%d %H:%M:%S") Backup GitLab Conf done" >> $BACKUP_DIR/gitlab_backup-cron-`date +\%F`.log
fi

# Remove files older than X days
find $BACKUP_DIR/* -mtime +$RETENTION -exec rm -rf {} \;

echo "$(date +"%Y-%m-%d %H:%M:%S") Backup Gitlab finished" >> $BACKUP_DIR/gitlab_backup-cron-`date +\%F`.log

