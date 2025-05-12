## slurm-utility
Useful utility commands for Slurm to aid HPC efficiency 

### 1. inspect_gpu_usage_by_node.sh

outputs gpu allocation usage node by node.

### example usage
```
git clone https://github.com/vwhvpwvk/slurm-utility.git
cd slurm-utility/
set_alias_bashrc.sh inspect_gpu_usage_by_node.sh gpu-usage
source ~/.bashrc
gpu-usage
```