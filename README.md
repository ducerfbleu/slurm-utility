## slurm-utility
Useful utility commands for Slurm to aid HPC efficiency 

### 1. inspect_gpu_usage_by_node.sh

outputs gpu allocation usage node by node.

### usage
```
cd $HOME
git clone https://github.com/vwhvpwvk/slurm-utility.git
cd slurm-utility/
bash set_alias_bashrc.sh inspect_gpu_usage_by_node.sh gpu-usage
source ~/.bashrc
gpu-usage
```

### to remove alias
```
vim ~/.bashrc
## delte alias set up line
unalias gpu-usage
```
