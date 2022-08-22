### ==================================
###              HYPERION
### ==================================

%lang starknet

### ========== dependencies ==========

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

from starkware.starknet.common.syscalls import get_block_timestamp

from src.utils.structs import _A

### ============= const ==============

const PRECISION = 100

### ======= storage variables ========

@storage_var
func n_tokens() -> (n_tokens : felt):
end

@storage_var
func tokens(token_index : felt) -> (token_address : felt):
end

@storage_var
func token_balance(token_index :  felt) -> (balance : felt):
end

@storage_var 
func _A_() -> (a : _A):
end

### ========== constructor ===========

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_len : felt, arr : felt*, A : felt):
    
    n_tokens.write(arr_len - 1)
    set_tokens(arr_len, arr)
    
    let (time) = get_block_timestamp()
    let a = _A(
        precision=PRECISION,
        initial_a=A * PRECISION,
        future_a=A * PRECISION,
        initial_a_time=time,
        future_a_time=time,
    )

    _A_.write(a)

    init_pool(arr_len - 1)
    return()
end

### ============= views ==============

@view
func get_token{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(token_index : felt) -> (token_address : felt):
    alloc_locals
    let (token_address) = tokens.read(token_index)
    return(token_address)
end

### ============ exchange ============

# param: i   index of the token to send
# param: j   index of the token to recieve
# param: _dx amount of the token to send
@external
func exchange{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(i : felt, j : felt, _dx : felt) -> (res : felt):
    alloc_locals

    let (arr) = alloc()
    let (n) = n_tokens.read()
    let (old_balances) = _xp(n, arr) 

    let x = old_balances[i] + _dx
    let y = get_y(i, j, x, old_balances) 
    
    return(x)
end

### =============== _y ===============

func get_y{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(i : felt, j : felt, _dx : felt, _xp : felt*) -> (y : felt):
    alloc_locals

    let (A) = get_A()
    let (D) = get_D(A , _xp)


    return(y=0)
end

### =============== _D ===============

func get_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(A : felt, _xp : felt*) -> (D : felt):

    return(D=0)
end

### ==============  A  ===============

func get_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (A : felt):


    return(A=0)
end

### ============= utils ==============

func set_tokens{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_len : felt, arr : felt*):
    alloc_locals

    if arr_len == 0:
        return()
    end

    tokens.write(arr_len, arr[arr_len - 1])
    set_tokens(arr_len - 1, arr)
    return()
end

func _xp{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(n : felt, arr : felt*) -> (res : felt*):
    alloc_locals
    
    if n == 0:
        return(arr)
    end

    let (x) = token_balance.read(n)
    assert [arr + n] = x
    let (res) = _xp(n - 1, arr)
    return(res)
end


# until we build out the pool this will set the initial state for testing
func init_pool{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(n : felt):
    if n == 0:
        return()
    end

    token_balance.write(n, 1000)
    init_pool(n - 1)
    return()
end


