#!/bin/bash

# Définir la région AWS et le profil si nécessaire
AWS_PROFILE="879381257984_AWS-Sandbox-AdminAccess"
AWS_REGION="eu-west-1"

# Liste des stacks à supprimer, dans l'ordre inverse
STACKS=(
  Stack-ALB-FRONT
  Stack-frontend-AutoScaling
  Stack-ALB-BACKEND
  Stack-bastion
  Stack-backend-AutoScaling
  Stack-rds-snapshot
  Stack-Endpoint
  Stack-Security
  Stack-IAM
  Stack-network
)

# Fonction pour supprimer une stack
for STACK_NAME in "${STACKS[@]}"; do
  echo "Suppression du stack : $STACK_NAME"
  aws cloudformation delete-stack \
    --stack-name $STACK_NAME \
    --profile $AWS_PROFILE \
    --region $AWS_REGION

  echo "Attente de la suppression du stack : $STACK_NAME"
  aws cloudformation wait stack-delete-complete \
    --stack-name $STACK_NAME \
    --profile $AWS_PROFILE \
    --region $AWS_REGION

  echo "Stack supprimé : $STACK_NAME"
done
