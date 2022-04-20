# 
#helm dependency update ./
helm upgrade --install acs ./ \
--set externalPort="443" \
--set externalProtocol="https" \
--set externalHost="kubedev.arkcase.com" \
--set persistence.enabled=true \
--set persistence.storageClass.enabled=true \
--set persistence.storageClass.name="efs-sc" --dry-run
#--atomic \
#--timeout 10m0s 
