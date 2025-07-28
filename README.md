# deerhide_docker_svn_server
Docker Server to handle SVN Services Hosting

## Objective
    - P0: Provide SVN Services to multiple User
    - P0: Provide Multiple SVN Repositories
    - P0: Ensure Security on the SVN Connection as hard as possible with concern about User Experience and Facility
    - P1: Configuration, User, Repo need to be actualize as simple as possible (without complexity issue)
    - P2: Provide Monitoring Capacity on Service Usage, Health

## Proposal
 - Use SSH as hardering layer between User and Service
    - SSH Connection is a "classic" to monitor and do the hardering
 - Use User Certificate Authentication to pass the first layer of connection to SVN
    - More simple usage and don't need rotation as password
    - Certificate management can be also centralize (Hashicorp Vault Signature and CA)
 - Provide Basic Authentication (on top of ssh connection)
    - Final ACL will be handle by subversion classicaly
 - User Certificate must be sign by Hashicorp Vault SSH Authority
    - Container need only to know the Public CA to verify all User Signed Certificate
    - Certificate Signature provide the username on the container system and force it
    - Each User will have a unix user on the container image (with limited rights)