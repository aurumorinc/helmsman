```
kubectl -n chatwoot exec -it deploy/chatwoot-web -- bin/rails runner "InstallationConfig.find_by(name: 'ENABLE_ACCOUNT_SIGNUP')&.update(value: true)"
```
```
kubectl -n chatwoot exec -it deploy/chatwoot-web -- bin/rails runner "InstallationConfig.find_by(name: 'ENABLE_ACCOUNT_SIGNUP')&.update(value: false)"
```
```
kubectl delete job chatwoot-migrate -n chatwoot
```