#!/bin/bash
#

BASE_DIR=$1
REPOSERVER=$2
REPOPATH=$3
SERVERNAME=$4
AIRFLOW=$5
S3SERVER=$6
REPLICAS=$7
SURGE=$8
SQLALCHEMY_DATABASE_URI=$9


YORIG="$BASE_DIR/OS_val_template"
YFILE="$BASE_DIR/OS_values.yaml"
echo "Using $YORIG as template to create $YFILE"
cp -f $YORIG $YFILE
sed -i "s|REPOSITORY|$REPOSERVER|g" $YFILE
sed -i "s|REPOPATH|$REPOPATH|g" $YFILE
sed -i "s|SERVERNAME|$SERVERNAME|g" $YFILE
sed -i "s|AIRFLOW|$AIRFLOW|g" $YFILE
sed -i "s|S3_SERVER|$S3SERVER|g" $YFILE
sed -i "s|REPLICAS|$REPLICAS|g" $YFILE
sed -i "s|SURGE|$SURGE|g" $YFILE


if [ "$SQLALCHEMY_DATABASE_URI" == "x" ];then
    echo "no sqlalchemy database uri provided"
else
    # sed -ie '/internalDB/ s/true/false/' $YFILE
    sed -i 's|internalDB: true|internalDB: false|g' $YFILE
fi

if [ "$REPOSERVER" != "x" ]; then
    sed -i "s|# repository:|repository:|g" $YFILE
    sed -i "s|# flair:|flair:|g" $YFILE
fi

