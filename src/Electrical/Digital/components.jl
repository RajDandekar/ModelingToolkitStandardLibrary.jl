# Adders
"""
```julia
function HalfAdder(; name)
```

Takes two bits as input, and outputs the sum and the carry

# States
- `sum(t)`
  The sum of the input bits
- `carry(t)`
  The carry generated by the input bits

# Connectors
- `x1`, `x2`
  The two inputs to add
- `y1`
  Output [`DigitalPin`](@ref) corresponding to the sum
- `y2`
  Output [`DigitalPin`](@ref) corresponding to the carry
"""
function HalfAdder(; name)
    @named x1 = DigitalPin()
    @named x2 = DigitalPin()
    @named y1 = DigitalPin()
    @named y2 = DigitalPin()
    @variables sum(t), carry(t)

    eqs = [
        y1.val ~ _xor(x1.val, x2.val)
        y2.val ~ _and(x1.val, x2.val)
        sum ~ y1.val
        carry ~ y2.val
    ]
    ODESystem(eqs, t, [sum, carry], [], systems=[x1, x2, y1, y2], name=name)
end

"""
```julia
function FullAdder(; name)
```

Takes three bits as input, and outputs the sum and the carry

# States
- `sum(t)`
  The sum of the input bits
- `carry(t)`
  The carry generated by the input bits

# Connectors
- `x1`, `x2`, `x3`
  The three inputs to add
- `y1`
  Output [`DigitalPin`](@ref) corresponding to the sum
- `y2`
  Output [`DigitalPin`](@ref) corresponding to the carry
"""
function FullAdder(; name)
    @named x1 = DigitalPin()
    @named x2 = DigitalPin()
    @named x3 = DigitalPin() 
    @named y1 = DigitalPin()
    @named y2 = DigitalPin()
    @variables sum(t), carry(t)

    eqs = [
        y1.val ~ _xor(x1.val, x2.val, x3.val)
        y2.val ~ _or(_and(x3.val, _xor(x1.val, x2.val)), _and(x1.val, x2.val))
        sum ~ y1.val
        carry ~ y2.val
    ]
    ODESystem(eqs, t, [sum, carry], [], systems=[x1, x2, x3, y1, y2], name=name)
end

# Multiplexers

# This selects data from the `N` input ports (`d₀` to `dₙ₋₁`) 
# using values of `n` select lines, where `N = 2^n` 
"""
```julia
function MUX(; name, N=4)
```

Standard Multiplexer. Selects data from `N` input ports using the values
of `n` select lines, where `N=2ⁿ`. For the `i`th input port to be selected,
the values of the select lines should correspond to the binary representation
of `i`.

# Connectors
- `d1`, `d2`, ...
  The `N` input lines
- `s1`, `s2`, ...
  The `n` select lines
- `y`
  The output, selected from one of the `N` input lines
"""
function MUX(; name, N=4)
    n = log2(N)
    try n = Int(n) catch(e) throw("`N` must be a power of 2") end
    s = map(0:n-1) do i
        DigitalPin(; name=Symbol(:s, i))
    end
    d = map(0:N-1) do i
        DigitalPin(; name=Symbol(:d, i))
    end
    @named y = DigitalPin()

    nodes = Num[]
    for i in 1:N
        bin = digits!(zeros(Int64,n), i-1, base=2)
        statelist = Term{Real, Nothing}[]
        for j in 1:n
            varstate = bin[j] == 0 ? _not(s[j].val) : s[j].val
            push!(statelist, varstate)
        end
        push!(nodes, _and(statelist..., d[i].val))
    end

    eqs = Equation[
        y.val ~ _or(nodes...)
    ]

    ODESystem(eqs, t, [], [], systems=[d..., s..., y], name=name)
end

# This selects one of the `N` output ports (`y₀` to `yₙ₋₁`) 
# to transmit data `d` using values of `n` select lines, where `N = 2^n` 
"""
```julia
function DEMUX(; name, N=4)
```

Standard Demultiplexer. Performs the reverse operation of a [`MUX`](@ref).
Selects one of the `N` output ports to transmit the input `d` using the
values of `n` select lines, where `N=2ⁿ`. For the `i`th output port to be
selected, the values of the select lines should correspond to the binary
representation of `i`.

# Connectors
- `d`
  The input to be transmitted to one of the output lines
- `s1`, `s2`, ...
  The `n` select lines
- `y1`, `y2`, ...
  The `N` output lines
"""
function DEMUX(; name, N=4)
    n = log2(N)
    try n = Int(n) catch(e) throw("`N` must be a power of 2") end
    @named d = DigitalPin()
    s = map(0:n-1) do i
        DigitalPin(; name=Symbol(:s, i))
    end
    y = map(0:N-1) do i
        DigitalPin(; name=Symbol(:y, i))
    end

    eqs = Equation[]
    for i in 1:N
        bin = digits!(zeros(Int64,n), i-1, base=2)
        statelist = Term{Real, Nothing}[]
        for j in 1:n
            varstate = bin[j] == 0 ? _not(s[j].val) : s[j].val
            push!(statelist, varstate)
        end
        push!(eqs, y[i].val ~ _and(statelist..., d.val))
    end

    ODESystem(eqs, t, [], [], systems=[d, s..., y...], name=name)
end

# Encoder-Decoder

# Encodes `N` inputs to `n` outputs, where `N = 2^n`
"""
```julia
function Encoder(; name, N=4)
```

Encodes `N` inputs to `n` outputs,  where `N=2ⁿ`. Exactly one of the inputs should be `1`.
If the `i`th input is `1`, then the output corresponds to the binary representation of `i`.

# Connectors
- `d1`, `d2`, ...
  The `N` input lines
- `y1`, `y2`, ...
  The `n` output lines
"""
function Encoder(; name, N=4)
    n = log2(N)
    try n = Int(n) catch(e) throw("`N` must be a power of 2") end
    d = map(0:N-1) do i
        DigitalPin(; name=Symbol(:d, i))
    end
    y = map(0:n-1) do i
        DigitalPin(; name=Symbol(:y, i))
    end

    nodes = Vector{Term{Real, Nothing}}[]
    i = 0
    for j in 1:n
        counter = 1
        statelist = Term{Real, Nothing}[]
        while i < N
            while counter <= 2^j
                counter > 2^(j-1) && push!(statelist, d[i+1].val)
                counter += 1
                i = i+1
            end
            counter = 1
        end
        i = 0
        push!(nodes, statelist)
    end

    eqs = Equation[]
    for i in n:-1:1
        push!(eqs, y[i].val ~ _or(nodes[i]...))
    end

    ODESystem(eqs, t, [], [], systems=[d..., y...], name=name)
end

# Decodes `n` inputs to `N` outputs, where `N = 2^n`
"""
```julia
function Decoder(; name, n=2)
```

Performs the reverse operation of an [`Encoder`](@ref). Decodes `n` inputs
to `N` outputs,  where `N=2ⁿ`. The `i`th output is `1` if the values of
the select lines correspond to the binary representation of `1`.

# Connectors
- `d1`, `d2`, ...
  The `n` input lines
- `y1`, `y2`, ...
  The `N` output lines
"""
function Decoder(; name, n=2)
    N = 2^n
    d = map(0:n-1) do i
        DigitalPin(; name=Symbol(:d, i))
    end
    y = map(0:N-1) do i
        DigitalPin(; name=Symbol(:y, i))
    end

    nodes = Vector{Term{Real, Nothing}}[]
    for i in 1:N
        bin = digits!(zeros(Int64, n), i-1, base=2)
        statelist = Term{Real, Nothing}[]
        for j in 1:n
            varst = bin[j] == 0 ? _not(d[j].val) : d[j].val
            push!(statelist, varst)
        end
        push!(nodes, statelist)
    end

    eqs = Equation[]
    for i in N:-1:1
        push!(eqs, y[i].val ~ _and(nodes[i]...))
    end

    ODESystem(eqs, t, [], [], systems=[d..., y...], name=name)
end