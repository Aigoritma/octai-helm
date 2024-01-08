# octai-helm

## External Secrets Operator in GCP

**Set up the necessary env variables.**

export GCP_PROJECT_ID="your-project-name"
export ESO_GCP_SERVICE_ACCOUNT=external-secrets
export ESO_K8S_NAMESPACE=external-secrets
export ESO_K8S_SERVICE_ACCOUNT=external-secrets

**Set up workload identity resources for ESO.**

```
#Create GCP service account
gcloud iam service-accounts create $ESO_GCP_SERVICE_ACCOUNT \
--project=$GCP_PROJECT_ID
```

```
#Create IAM role bindings
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
--member "serviceAccount:$ESO_GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
--role "roles/secretmanager.secretAccessor"

```
```
#Allow kubernetes service account to impersonate GCP service account
gcloud iam service-accounts add-iam-policy-binding $ESO_GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$GCP_PROJECT_ID.svc.id.goog[$ESO_K8S_NAMESPACE/$ESO_K8S_SERVICE_ACCOUNT]"
```

**Install External Secrets Operator(ESO).**

helm repo add external-secrets https://charts.external-secrets.io

helm upgrade -install external-secrets external-secrets/external-secrets \
    --set 'serviceAccount.annotations.iam\.gke\.io\/gcp-service-account'="$ESO_GCP_SERVICE_ACCOUNT@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
    --namespace external-secrets \
    --create-namespace \
    --debug \
    --wait