# Benchmark Results

## Hardware:

Intel(R) Core(TM) i7-5820K CPU @ 3.30GHz
Ubuntu 16.04
16 Gb RAM

## Software:

Julia 0.7.0-DEV.3580
TypeSortedCollections.jl 6dfa66e780fc2560a47288803248c3774dd7f7f7

## Results:

```
container = SpecializedContainer
Adding constraints:       1.706 μs (55 allocations: 7.34 KiB)
Iterating over constraints:       3.826 μs (123 allocations: 13.08 KiB)
container = TypeContainer
Adding constraints:       7.989 μs (174 allocations: 11.25 KiB)
Iterating over constraints:       3.784 μs (123 allocations: 13.08 KiB)
container = IDContainer
Adding constraints:       5.853 μs (70 allocations: 8.00 KiB)
Iterating over constraints:       3.753 μs (123 allocations: 13.08 KiB)
container = IDVectContainer
Adding constraints:       3.877 μs (61 allocations: 7.78 KiB)
Iterating over constraints:       3.745 μs (123 allocations: 13.08 KiB)
container = ErasedContainer
Adding constraints:       1.791 μs (154 allocations: 8.19 KiB)
Iterating over constraints:       4.978 μs (123 allocations: 13.08 KiB)
container = TypeSortedContainer
Adding constraints:       28.275 μs (579 allocations: 31.36 KiB)
Iterating over constraints:       3.979 μs (123 allocations: 13.08 KiB)
```

