#!/bin/bash

set -euo pipefail

AWS_PROFILE="879381257984_AWS-Sandbox-AdminAccess"
AWS_REGION="eu-west-1"
ENV_NAME="dev"

function deploy_stack() {
  local stack_name=$1
  local template_file=$2
  shift 2
  echo "Déploiement de $stack_name"
  aws cloudformation deploy \
    --template-file "$template_file" \
    --stack-name "$stack_name" \
    --parameter-overrides EnvironmentName=$ENV_NAME "$@" \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"

  echo "Attente de la création du stack $stack_name"
  aws cloudformation wait stack-create-complete \
    --stack-name "$stack_name" \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION"
}

#################################################
### Récupérer le dernier snapshot automatique ###
#################################################
echo "Recherche du dernier snapshot disponible pour la base RDS"

# 1. Chercher un snapshot MANUEL
SNAPSHOT_ID=$(aws rds describe-db-snapshots \
  --snapshot-type manual \
  --db-instance-identifier dev-DATABASE \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --query "reverse(sort_by(DBSnapshots, &SnapshotCreateTime))[0].DBSnapshotIdentifier" \
  --output text)

# 2. Si aucun snapshot manuel trouvé, fallback vers snapshot AUTOMATIQUE
if [ "$SNAPSHOT_ID" == "None" ] || [ -z "$SNAPSHOT_ID" ]; then
  echo "Aucun snapshot manuel trouvé. Recherche du snapshot automatique..."
  SNAPSHOT_ID=$(aws rds describe-db-snapshots \
    --snapshot-type automated \
    --db-instance-identifier dev-DATABASE \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --query "reverse(sort_by(DBSnapshots, &SnapshotCreateTime))[0].DBSnapshotIdentifier" \
    --output text)
fi

if [ "$SNAPSHOT_ID" == "None" ] || [ -z "$SNAPSHOT_ID" ]; then
  echo "Aucun snapshot disponible trouvé. Abandon du déploiement de la base."
  exit 1
fi

echo "Snapshot à utiliser : $SNAPSHOT_ID"


echo "Dernier snapshot automatique trouvé : $SNAPSHOT_ID"
ID_snap="$SNAPSHOT_ID"


#######################################
#         Lancement des stacks        #
#######################################
#1
deploy_stack "Stack-network" "Stack-network.yaml"

#2
deploy_stack "Stack-IAM" "Stack-IAM.yaml"

#3
deploy_stack "Stack-Security" "Stack-Security.yaml" \
  MyPublicIp="129.222.109.226/32"

#4
deploy_stack "Stack-Endpoint" "Stack-Endpoint.yaml"

#5
# deploy_stack "Stack-rds-snapshot" "Stack-rds-snapshot.yaml" \
#   DBSnapshotIdentifier="$ID_snap"
aws cloudformation deploy \
    --template-file Stack-rds-snapshot.yaml \
    --stack-name Stack-rds-snapshot \
    --parameter-overrides \
        EnvironmentName=$ENV_NAME \
        DBSnapshotIdentifier=$ID_snap \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile $AWS_PROFILE \
    --region $AWS_REGION

echo "Attente ......"
aws cloudformation wait stack-create-complete \
    --stack-name Stack-rds-snapshot \
    --profile $AWS_PROFILE \
    --region $AWS_REGION
  
#6
deploy_stack "Stack-backend-AutoScaling" "Stack-backend-AutoScaling.yaml"

#7
deploy_stack "Stack-bastion" "Stack-bastion.yaml"

#8
deploy_stack "Stack-ALB-BACKEND" "Stack-ALB-BACKEND.yaml"

#9
deploy_stack "Stack-frontend-AutoScaling" "Stack-frontend-AutoScaling.yaml"

#10
deploy_stack "Stack-ALB-FRONT" "Stack-ALB-FRONT.yaml"

echo "Tous les stacks ont été déployés avec succès."