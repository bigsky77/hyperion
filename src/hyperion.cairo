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






