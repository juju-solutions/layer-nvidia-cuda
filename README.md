# Installing CUDA on GPU enabled hardware

This simple charm installs the CUDA driver on a blank image running on a GPU instance. It first test if a GPU from nVidia is installed. If yes, it will install CUDA. Otherwise, it will exit in error. 

## Usage

Deploy a GPU enabled instance. For example, on AWS:


```
juju deploy --constraints "instance-type=g2.2xlarge" trusty/ubuntu ubuntu-gpu
```

Then install the CUDA charm 

```
juju deploy cs:~samuel-cozannet/trusty/cuda
juju add-relation ubuntu-gpu cuda
```
