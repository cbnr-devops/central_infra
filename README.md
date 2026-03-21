# central_infra
1. KMS issues - To remove KMS resources:
 - Run (Inside dev and staging): 
    ```bash
      terraform state list | grep kms
    ```
 - And remove all entries: 
    ```bash
      terraform state rm '<resource>'
    ```
2. Managing the auth issues by adding respective blocks to the eks module is not working. So removed that part and added the permissions manually.
 - Run:
    '''bash
      aws eks update-kubeconfig --region ap-southeast-2 --name dev-cluster
    ''' 
3. Adding access entry to reach kube-apiserver:
 - Run:
   '''bash
     aws eks create-access-entry \
      --cluster-name dev-cluster \
      --principal-arn arn:aws:iam::312018064574:user/ec2-cli-user
   '''
 
   '''bash
     aws eks associate-access-policy \
       --cluster-name dev-cluster \
       --principal-arn arn:aws:iam::312018064574:user/ec2-cli-user \
       --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
       --access-scope type=cluster
   '''


