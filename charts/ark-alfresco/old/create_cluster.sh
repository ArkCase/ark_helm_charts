eksctl create cluster \
--name alfresco-eks \
--version 1.21 \
--region us-east-1 \
--zones us-east-1a,us-east-1b \
--nodegroup-name alfresco-linux-nodes \
--nodes 2 \
--node-type m5.xlarge \
--nodes-min 0 \
--nodes-max 2 \
--with-oidc \
--ssh-access \
--ssh-public-key "~/.ssh/armcsbs-public.pub" \
--managed

