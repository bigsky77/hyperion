### ==================================
###              HYPERION
### ==================================

%lang starknet
%builtins pedersen range_check 

### ============ glossary ============

# xp - array of token balances  
# j - index of coin to receive
# i - index coin to send
# dx - amount of 'i' being exchanged
# dy - amount of 'j' to receive

### ========== dependencies ==========

# starkware cairo-std
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, assert_lt, assert_not_equal, assert_nn
from starkware.cairo.common.math_cmp import is_le 
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import (get_caller_address, get_contract_address)

# starkware starknet-std
from starkware.starknet.common.syscalls import get_block_timestamp

# openzeppelin
from src.openzeppelin.token.erc20.IERC20 import IERC20

# internal utils
from src.utils.structs import _A 

### =========== constants ============

const A_PRECISION = 100 

### ======= storage variables ========

@storage_var
func n_tokens() -> (value : felt):
end

@storage_var
func tokens(token_index : felt) -> (token_address : felt):
end

@storage_var
func _A_() -> (_A : _A):
end

### ============= events =============

@event
func Swap():
end

@event 
func Mint():
end

@event
func Burn():
end

@event
func Ramp():
end

@event 
func Stop_Ramp():
end

### ========== constructor ===========

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(tokens_len : felt, tokens : felt*):
    alloc_locals

    n_tokens.write(value=tokens_len)
    set_token_index(tokens_len, tokens)

    return()
end

### ======== view-functions ==========

@view
func get_pool_balance{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(index : felt) -> (balance : Uint256):
    alloc_locals

    let (pool_address) = get_contract_address()
    let (token_address) = tokens.read(index)
    let (balance) = IERC20.balanceOf(token_address, pool_address)
    
    return(balance)
end

### =============== _A ===============

# this will eventually be rolled into the constructor - but keeping seperate for now
@external
func set_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(initial_a : felt, future_a : felt, initial_a_time : felt, future_a_time : felt):
    alloc_locals
    
    let a = _A(
        precision=A_PRECISION, 
        initial_a=initial_a, 
        future_a=future_a, 
        initial_a_time=initial_a_time, 
        future_a_time=future_a_time)
    
    _A_.write(value=a)
    
    return()
end

func get_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (res : felt):
    alloc_locals
    
    let (A) = _A_.read()

    let t1 = A.future_a_time
    let A1 = A.future_a
    let (block_time_stamp) = get_block_timestamp()
     
    # block_time_stamp < t1
    let (x) = is_le(block_time_stamp, t1 - 1)

    # if block_time_stamp > t1
    if x == 0: 
        return(res=A1)
    end

    let A0 = A.initial_a
    let t0 = A.initial_a_time

    # A1 > A0
    let (y) = is_le(A0, A1 - 1)
    
    # if A1 < A0 
    if y == 0:
        let res = A0 - (A0 - A1) * (block_time_stamp * t0) / (t1 - t0) 
        return(res)
    end

    # if A1 > A0
    let res = A0 + (A1 - A0) * (block_time_stamp * t0) / (t1 - t0)

    return(res)
end

### =============== _D ===============

@external
func get_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}() -> (res : felt):
    alloc_locals

    # setting in the function instead of passing as variable 
    let (xp_len, xp) = _xp()
    let (amp) = get_A()
    
    let Dprev = Uint256(0, 0)

    let (n) = n_tokens.read()
    # array sum of balances
    let (S) = arr_sum(n, xp)
    
    if S == 0:
        return(0)
    end
    
    let loop_len = 255
    let Ann = amp * n
    let D_start = S
    
    let (res) = calc_D(loop_len, Ann, D_start, xp_len, xp, S)

    return(res)
end

# notice: These three functions can probably be put into one 
func calc_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(n : felt, Ann : felt, D : felt, xp_len : felt, _xp : felt*, S : felt) -> (D : felt):
    alloc_locals

    # n should never = 0
    if n == 0:
        return(0)
    end

    let (A) = get_A()
    let (n_coins) = n_tokens.read()

    let (D_P) = ramp_DP(xp_len, _xp, D, D)
    let D_prev = D
    
    let D_new = (Ann * S  / A * D_P * n_coins ) * D / ((Ann * A) * D / A + (n_coins + 1) * D_P) 
    
    # if D_new > D_prev
    let (x) = is_le(D_prev, D_new - 1)
        if x == 0:
            let (D) = calc_D(n - 1, Ann, D_new, xp_len, _xp, S)
            return(D)
        end
    
    # is D_new - D_prev <= 1
    let (y) = is_le(D_new - D_prev, 1)
         if y == 0:
            let (D) = calc_D(n - 1, Ann, D_new, xp_len, _xp, S)
            return(D)
        end
    # is D_prev - D_new <= 1     
    let (z) = is_le(D_prev - D_new, 1)
        if z == 0:
            let (D) = calc_D(n - 1, Ann, D_new, xp_len, _xp, S)
            return(D)
        end

    return(D)
end

func ramp_DP{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(xp_len : felt, _xp : felt*, D_P : felt, D : felt) -> (DP : felt):
    alloc_locals

    let (n) = n_tokens.read()

    if xp_len == 0:
        return(0)
    end

    if D_P == 0:
        let res = (D * D) / (_xp[n - 1] * n)
        ramp_DP(xp_len - 1, _xp, res, D)
    end

    let x = D_P * D / (_xp[n - 1] * n)
    let (res) = ramp_DP( xp_len - 1, _xp, x, D)
    return(res)
end

### =============== xp ===============

# notice: returns an array of token balances 
@view
func _xp{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (res_len : felt, res : felt*):
    alloc_locals
    
    local arr : Uint256*

    let (n) = n_tokens.read()
    let res : felt* = get_xp(n, arr)

    return(n, res)
end

func get_xp{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(n : felt, arr : Uint256*) -> (res : felt*):
    alloc_locals
    
    if n == 0:
        return(arr)
    end

    let (address) = get_contract_address()
    let (token_) = tokens.read(n)
    let (bal) = IERC20.balanceOf(token_, address)
     
    assert [arr + n] = bal

    let (res) = get_xp(n - 1, arr + 1)
    return(res)
end

### ============== swap ==============

### ============== mint ==============

### ============== burn ==============

### =============== _y ===============

func get_y{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(i : felt, j : felt, x : felt, _xp : felt*) -> (res : felt):
    # i index value of coin to send 
    # j index value of the coin to receive
    # x = _dx + xp[i] 

    alloc_locals 
    
    let (n_coins) = n_tokens.read()

    assert_not_equal(i, j)
    assert_nn(j)
    assert_lt(j, n_coins)

    # safety checks
    assert_nn(i)
    assert_lt(i, n_coins)

    let (A) = get_A()
    let (D) = get_D()
    let Ann = A * n_coins
   
    let (S) = find_S(n_coins, i, j, x, _xp)
    
    # writing algorythm for 2 coins for now - this simplifies the loop a bit
    let _c = D * D / (x * n_coins)
    # this should be A_PRECISION using A to simpify for now 
    let c = _c * D * A / (Ann * n_coins)
    let b = S + D * A / Ann
    let y = D
    let n = 255
    
    let (res) = y_loop(n, y, c, b, D)

    return(res)
end

func y_loop{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(n : felt, y : felt, c : felt, b : felt, D : felt) -> (res : felt):
    alloc_locals
    
    if n == 0:
        return(0)
    end

    let y_prev = y
    let _y = (y * y + c) / (2 * y + b - D)
    
    # y_prev < y 
    let (e) = is_le(y_prev, _y - 1)
    
    if e != 0:
        let (v) = is_le(_y - y_prev, 1)
        if v != 0:
            return(_y)
        end
    end

    let (z) = is_le(y_prev - _y, 1)
        if z != 0:
            return(_y)
    end 

    let (res) = y_loop(n - 1, y_prev, c, b, D)
    return(res)
end

# do not need to use this function if n_coins < 3
func find_S{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(
    n : felt, 
    i : felt, 
    j : felt, 
    x : felt, 
    _xp : felt*) -> (res : felt): 
    alloc_locals

    # not the most elegant solution and may not work, but captures the logic
    if n == 0:
        return(0)
    end

    if i == j:
        return(0)
    end 
   
    if i == n:
       return(x)
    end
    
    if i != j:
        return(_xp[i])
    end

    let (res) = find_S(n - 1, i, j, x, _xp)
    return(res=[_xp] + res)
end

### ============= utils ==============

func set_token_index{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(arr_len : felt, arr : felt*) ->(res : felt):
    if arr_len == 0:
        return(0)
    end

    tokens.write(token_index=arr_len, value=arr[arr_len -1])
    let (res) = set_token_index(arr_len - 1, arr)
    return(res)
end

func arr_sum{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(arr_len : felt, arr : felt*) -> (arr_sum : felt):
    alloc_locals

    if arr_len == 0:
        return(0)
    end

    let (sum_of_rest) = arr_sum(arr_len - 1, arr + 1)
    return(arr_sum=[arr] + sum_of_rest)
end







