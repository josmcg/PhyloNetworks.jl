#Parallel Computation

Some SNaQ tools can be used in parallel out of the box. For example to call
`bootsnaq` in parallel:


```julia
addprocs(4)
bootsnaq(...)

```
This will run bootsnaq on 4 processors, assuming your machine has 4 processors.
You may add more processors than your machine has, but you will not receive any
performance benefits.

##Note about seeding
Because seeds are generated per processor, running tasks with different number
of processors may generate different results.

