### ==================================
###              HYPERION
### ==================================

%lang starknet

### ========== dependencies ==========

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.registers import get_fp_and_pc

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
    
    n_tokens.write(arr_len)
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
    assert [arr] = 0
    let (arr_len) = n_tokens.read()
    let (old_balances) = _xp(arr_len, arr) 
   
    let x = old_balances[i] + _dx
    #let (y) = get_y(i, j, x, arr_len, old_balances) 
    
    return(old_balances[2])
end

### =============== _y ===============

func get_y{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(i : felt, j : felt, _dx : felt, xp_len : felt, _xp : felt*) -> (y : felt):
    alloc_locals

    let (n) =n_tokens.read()
    let (A) = get_A()
    let (D) = get_D(A , n, _xp)
    let Ann = A * n
    
    let counter = 0
    let _c = 0
    let (S) = find_S(counter, i, j, _dx, xp_len, _xp)
    let (C) = find_C(xp_len, _xp, counter, D, n)

    return(y=0)
end

func find_S{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(counter : felt, i : felt, j : felt, x : felt, xp_len : felt, _xp : felt*) -> (res : felt):
    alloc_locals
    
    if xp_len == 0:
        return(0)
    end

    if j == xp_len:
        return(0)
    end

    if i == xp_len:
        let (res) = find_S(x, i, j, x, xp_len - 1, _xp)
        return(res)
    end

    let y = counter + _xp[xp_len]
    let (res) = find_S(y, i, j, x, xp_len - 1, _xp)
    return(res)
end

func find_C{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(xp_len : felt, _xp : felt*, counter : felt, D : felt, n : felt) -> (res : felt):
    alloc_locals

    if xp_len == 0:
        return(0)
    end

    let c = counter

        if c == 0:
            let y = c * D / (_xp[xp_len] * n)
            let (res) = find_C(xp_len - 1, _xp, y, D, n)
            return(res)
        end

    let y = c * D / (_xp[xp_len] * n)
    let (res) = find_C(xp_len - 1, _xp, y, D, n)
    return(res)
end


### =============== _D ===============

func get_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(A : felt, xp_len : felt, _xp : felt*) -> (D : felt):
    alloc_locals 

    let (S) =  array_sum(xp_len, _xp)

    if S == 0:
        return(0)
    end

    let D = S
    let Ann = A * xp_len
    let count = 255

    let (D) = d_recursion(count, S, D, Ann, xp_len, _xp)

    return(D)
end

func d_recursion{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(count : felt, S : felt, D : felt, Ann : felt, xp_len : felt, _xp : felt*) -> (res : felt):
    alloc_locals
    
    let (n) = n_tokens.read()
    # should never reach 0 
    if count == 0:
        return(0)
    end

    let (A) = get_A()
    let (D_P) = D_P_recursion(D, D, xp_len, _xp)
    let D_new = (Ann * S / A + D_P * n) * D / ((Ann - A) * D / A + (n + 1) * D_P)

    # D_new > D
    let (y) = is_le(D, D_new - 1)
        if y != 0:
            let (z) = is_le(D_new - D, 1)
                if z != 0:
                    return(D_new)
                end
        end

    let (x) = is_le(D - D_new, 1)
        if x != 0:
            return(D_new)
        end

    let (res) = d_recursion(count - 1, S, D_new, Ann, xp_len, _xp)
    return(res)
end

func D_P_recursion{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(D_P : felt, D : felt, xp_len : felt, _xp : felt*) -> (D_P_ : felt):
    alloc_locals

    let (n) = n_tokens.read()
    if xp_len == 0:
        return(0)
    end

    let res = D_P * D / (_xp[xp_len] * n)
    let (D_P_) = D_P_recursion(res, D, xp_len - 1, _xp)
    return(D_P_)
end

### ==============  A  ===============

func get_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (A : felt):
    alloc_locals

    let (_a) = _A_.read()
    
    let t1 = _a.future_a_time
    let A1 = _a.future_a

    let (block_time_stamp) = get_block_timestamp()

        # if blocktime < t1
        let (x) = is_le(block_time_stamp, t1 - 1)
        if x != 0: 
            let A0 = _a.initial_a
            let t0 = _a.initial_a_time
        
            # assert A1 > A0
            let (y) = is_le(A0, A1 - 1)
            if y != 0:
                let A = A0 + (A1 - A0) * (block_time_stamp - t0) / (t1 - t0)
                return(A)
            else:
                let A = A0 - (A0 - A1) * (block_time_stamp - t0) / (t1 - t0)
                return(A)
            end 
        end

    return(A1)
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

    let (x) = token_balance.read(n - 1)
    assert [arr] = x 
    
    _xp(n - 1, arr + 1)

    # should never reach here
    return(arr)
end

func array_sum{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(arr_len : felt, arr : felt*) -> (sum : felt): 
    if arr_len == 0: 
        return(0)
    end

    let (sum_of_rest) = array_sum(arr_len - 1, arr + 1)
    return(sum=[arr] + sum_of_rest)
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


