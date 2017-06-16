# Nvidia CUDA Layer

Installs CUDA and Nvidia drivers when supported GPU hardware is
detected.

The latest versions for the given architecture will be installed.


## States

The following states are set by this layer:


* `cuda.supported`

  This state is set when supported GPU hardware is detected.

* `cuda.installed'

  This state is set once CUDA and drivers are installed.


## Usage

To use this layer, include it in a charm and deploy the charm to a cloud
instance with Nvidia GPUs, e.g. `instance-type=p2.xlarge` on AWS or
`instance-type=Standard_NC6` on Azure.
