### ==================================
###              HYPERION
### ==================================

%lang starknet
%builtins pedersen range_check 

### ========== dependencies ==========

# starkware cairo-std
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, assert_lt
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
func _get_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}() -> (res : felt):
    alloc_locals

    # setting in the function instead of passing as variable 
    let (xp) = _xp()
    let (amp) = get_A()
    
    let Dprev = Uint256(0, 0)

    let (n) = n_tokens.read()
    # array sum of balances
    let (S) = arr_sum(n, xp)
    
    if S == 0:
        return(0)
    end

    let val = 255
    calc_D(val, S, S, amp)
    
    return(0)
end

func calc_D(val : felt, S : felt, D : felt, amp : felt) -> (res : felt):
    alloc_locals

    if val == 0:
        return(0)
    end

    let (dp) = D
    calc_DP(dp, S)

end

func calc_DP(n, dp, D) -> (dp : felt):
    alloc_locals
    
    if n == 0:
        return(0)
    end
    
    let num_tokens = n_tokens.read()
    let val_x = IERC20.balanceOf(n)

    let x = dp * D / (n * n_tokens)
    let (dp) = calc_DP(n - 1,  , D)

    return(dp)
end

### =============== xp ===============

# notice: returns an array of token balances 
func _xp{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}() -> (res : felt*):
    alloc_locals
    
    local arr : Uint256*

    let (n) = n_tokens.read()
    let res : felt* = get_xp(n, arr)

    return(res)
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







