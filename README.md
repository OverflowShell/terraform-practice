# Práctica de Terraform: una VM en Azure

Mi primera práctica con Terraform. Levanto una VM chica de Linux en Azure,
entro por SSH y después la destruyo. Todo en un grupo de recursos aparte
(`rg-terraform-practica`) para no tocar mi servidor real.

Ciclo completo probado el 11-11-2026: crear, entrar y borrar.
Al final confirmé que el grupo ya no existe en Azure.

## Qué crea

8 recursos: el grupo de recursos, una red virtual con su subred, una regla
de seguridad que solo deja pasar SSH (puerto 22), la IP pública, la tarjeta
de red y la VM `vm-tfpractica` (Ubuntu 22.04).

## Comandos

Primero la llave, y tiene que ser RSA: Azure no acepta ed25519 para crear
VMs (me salió ese error en el primer `plan`).

```powershell
ssh-keygen -t rsa -b 4096 -f $HOME\.ssh\terraform_practica_rsa
az login
```

El ciclo:

```powershell
terraform init      # descarga el proveedor de Azure (solo la primera vez)
terraform plan      # muestra qué haría, sin crear nada
terraform apply     # crea todo (pide confirmación)
ssh -i $HOME\.ssh\terraform_practica_rsa azureuser@<la IP que da el apply>
terraform destroy   # borra todo lo que creó
```

## Notas

- El `terraform.tfstate` no se sube a Git (está en el `.gitignore`).
  A GitHub solo van `main.tf`, `.terraform.lock.hcl` y este README.
- En el código va la llave **pública**. La privada no sale de mi PC.
