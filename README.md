# iplz: End-to-End Declarative Deployment Demo

_End-to-end declarative deployment_ means having a set of files describing the desired end state of the entire production pipeline, in such a way that we can materialize it with _a single command_.
In this case, that pipeline consists of building, provisioning, and deploying a simple web service to Amazon EC2.

I describe the ideas and methods in detail in the [accompanying tutorial blog post](https://jonascarpay.com/posts/2022-09-19-declarative-deployment.html).

The `iplz` application itself is a simple [`icanhazip.com`](http://icanhazip.com/) clone, it echoes the client's IP address back at them.
It serves as a stand-in for a larger application, see the [binplz.dev repo](https://github.com/binplz/binplz.dev) for how the ideas presented here work in a more complex situation.

### Usage

#### Setup

1. [Configure Terraform with your AWS credentials](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)

2. Run `nix run .#terraform -- init` to create Terraform lock files

#### Building and Deploying

1. `nix run .#terraform -- apply`

There is no step 2.

<p align="center">
<img src="https://intl.startrek.com/sites/default/files/images/2019-01/d7b431b1a0cc5f032399870ff4710743.jpeg" width="300" />
</p>
