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

# starkware starknet-std
from starkware.starknet.common.syscalls import get_block_timestamp

# openzeppelin
from src.openzeppelin.token.erc20.IERC20 import IERC20

# utils e
from src.utils.structs import _A

### =========== constants ============

const PRECISION = 18 ** 10
const A_PRECISION = 100
const N_COINS = 2
const RATES = 1 # placeholder

const TOKEN_A = 1
const TOKEN_B = 2

### ======= storage variables ========

@storage_var
func token_index_to_addr(token_index : felt) -> (token_address : felt):
end

@storage_var
func token_balances(token_index : felt) -> (token_balance : felt):
end

@storage_var
func factory() -> (factory_address : felt):
end

@storage_var
func fee() -> (fee : felt):
end

@storage_var
func admin_fee() -> (admin_fee : felt):
end

# amplification coeffiecent 
@storage_var
func _A_() -> (A : _A):
end

### ========== constructor ===========
 
@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
}(
        token_a_address : felt,
        token_b_address : felt, 
        A : felt,
        _fee : felt,
        _admin_fee : felt,
):
    with_attr error_message("Token cannot be from the zero address"):
        tempvar x = token_a_address * token_b_address
        assert_not_zero(x)
    end

    token_index_to_addr.write(token_index=TOKEN_A, value=token_a_address)
    token_index_to_addr.write(token_index=TOKEN_B, value=token_b_address)
 
    let a = _A(
       precision = A_PRECISION,
       initial_a = A * A_PRECISION,
       future_a = A * A_PRECISION,
       initial_a_time = 0, # hack
       future_a_time = 0, # hack
    )

    fee.write(_fee)
    admin_fee.write(_admin_fee)

    _A_.write(a)

    return()
end

### ======== view-functions ==========

@view
func get_A{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}()-> (res : felt):
    alloc_locals

    let (local block_timestamp) = get_block_timestamp()
    let (local _a_) = _A_.read()
    
    tempvar t1 = _a_.future_a_time
    tempvar A1 = _a_.future_a
   
    # hack: should be lt 
    let (local x) = is_le(block_timestamp, t1)
    
    jmp body if x != 0; ap++
        return(A1)
   
    body:
    tempvar A0 = _a_.initial_a
    tempvar t0 = _a_.initial_a_time
        
        # hack: should be lt
        let (local y) = is_le(A0, A1)
        
        jmp term if y != 0; ap++
            return(A0 - (A0 - A1) * (block_timestamp -  t0) / (t1 -t0))
       
        term:
            return(A0 - (A0 - A1) * (block_timestamp -  t0) / (t1 -t0)) 
end

@view
func getA{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}() -> (res : felt):
    alloc_locals

    let (local x) = get_A()
    let (local y) = _A_.read()

    return(x / y.precision)
end

@view
func _xp{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}() -> (xp_len : felt, xp : felt*):
    alloc_locals
    
    let (local token_a) = token_balances.read(TOKEN_A)
    let (local token_b) = token_balances.read(TOKEN_B)

    let (local xp : felt*) = alloc()

    # hack needs to be dynamic (also need to find the syntax for res.length)
    let (xp_len) = xp.SIZE 
    assert [xp + 0] = (RATES * token_a) / PRECISION
    assert [xp + 1] = (RATES * token_b) / PRECISION
    
    return(xp_len, xp)
end

@view
func get_D{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}() -> (res : felt):
    alloc_locals
    
    const RANGE = 255

    let (local xp_len, xp) = _xp()
    let (local Ann) = get_A()

    local Dprev : felt
    let (S) = arr_sum(xp_len, xp) 

    if S == 0:
        return(res=0)
    end

    body:
    tempvar D_P = 0
    tempvar D = S
    let (D_P) = calc_D_P(xp_len, xp, D, D_P) 
    
    tempvar D_prev = D
    let y = Ann * S / A_PRECISION + (D_P) * N_COINS * D 
    let x = (Ann - A_PRECISION) * D / A_PRECISION + (N_COINS + 1) * (D_P)
    let D = y / x
    
    # check that D >= D_prev 
    let (z) = is_le(D, D_prev)
    if z == 0:
        let (x1) = is_le(1, D - D_prev)
        if x1 == 0:
            return(D)
        end
 
     let (n) = is_le(D_prev - D, 1)
        return(D)
    end

    jmp body
end

### ============= utils ==============
@view
func calc_D_P{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(xp_len : felt, xp : felt*, D : felt, D_P : felt) -> (res : felt):
    alloc_locals

    if xp_len == 0:
        return(res=0)
    end

    let _xp = xp[xp_len]
    let new_D_P = (D_P * D) / (_xp * N_COINS) 
    
    if new_D_P == 0:
        let (y) = calc_D_P(xp_len - 1, xp, D, D)     
        return(y)
    end
    
    let (x) = calc_D_P(xp_len - 1, xp, D, D_P)
    return(x)
end

@view
func arr_sum{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
}(arr_len : felt, arr : felt*) -> (sum :felt):
    if arr_len == 0:
        return(sum=0)
    end

    let (sum_of_rest) = arr_sum(arr_len=arr_len -1, arr=arr + 1)
    return(sum=[arr] + sum_of_rest)
end








 
