#!/usr/bin/env bash
set -e

ENV=$1
DIR="terraform/environments/$ENV"

# Terraform formatting, init, validate
terraform -chdir=$DIR fmt -check -recursive
terraform -chdir=$DIR init -input=false
terraform -chdir=$DIR validate

# Linters
tflint --chdir=$DIR
tfsec $DIR

# Terraform plan -> JSON
terraform -chdir=$DIR plan -out=tfplan -input=false
terraform -chdir=$DIR show -json tfplan > plan.json

# OPA evaluation
opa eval --fail-defined --format json --data opa/policies --input $DIR/plan.json "data.terraform.aws.deny"
